import os
import asyncio
import multiprocessing
import structlog
from pathlib import Path
from typing import AsyncIterator, Optional

# Apply Windows-specific patches (Encoding, Stability)
if os.name == 'nt':
    try:
        from patch_windows import apply_patches
        apply_patches()
    except Exception:
        pass

# Windows CUDA stability environment variables
if os.name == 'nt':
    os.environ['GGML_CUDA_NO_VMM'] = '1'
    os.environ['CUDA_MODULE_LOADING'] = 'LAZY'
    # 1. Try torch lib directory (usually contains necessary CUDA DLLs)
    try:
        import torch
        _torch_lib = Path(torch.__file__).parent / "lib"
        if _torch_lib.exists():
            os.add_dll_directory(str(_torch_lib))
    except Exception:
        pass
    # 2. Try standard CUDA_PATH
    _cuda_path = os.environ.get('CUDA_PATH')
    if _cuda_path:
        _bin_path = Path(_cuda_path) / "bin"
        if _bin_path.exists():
            try:
                os.add_dll_directory(str(_bin_path))
            except Exception:
                pass

from huggingface_hub import hf_hub_download
from config.settings import settings

log = structlog.get_logger(__name__)


class LLMService:
    def __init__(self):
        self._llm = None
        self._tokenizer = None
        self._model_type: Optional[str] = None  # 'gguf' or 'transformers'
        self._client = None
        self._current_model: Optional[str] = None
        self._current_model_path: Optional[str] = None
        self._is_ready = False
        self._server_running = False
        self._server_process = None
        self._lock = asyncio.Lock()
        self._interrupt_chat = False  # Flag to interrupt direct inference
        import threading
        self._inference_lock = threading.Lock()

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    @property
    def current_model(self) -> Optional[str]:
        return self._current_model

    @property
    def current_model_path(self) -> Optional[str]:
        return self._current_model_path

    @property
    def server_running(self) -> bool:
        return self._server_running

    @property
    def cuda_active(self) -> bool:
        try:
            import llama_cpp
            return llama_cpp.llama_supports_gpu_offload()
        except Exception:
            return False

    # ── Startup ──────────────────────────────────────────────────────────────

    async def initialize(self) -> bool:
        """Initialize the LLM service — try existing server first, then local models."""
        self._is_ready = False
        self._current_model = None
        self._current_model_path = None

        if await self._try_connect_server():
            log.info("Connected to existing LLM server", url=settings.llm_server_url)
            return True

        # Check for local models
        all_models = list(settings.models_dir.rglob("*.gguf"))

        if not all_models:
            log.info("No models found. Downloading Qwen2.5 1.5B Instruct...")
            try:
                model_path = await self._download_default_model()
                if model_path:
                    await self.load_model(model_path)
            except Exception as e:
                log.error(f"Failed to download default model: {e}")
                log.warning("Please load a model manually in the Models tab")
        else:
            # 1. Try to find the exact default model specified in settings
            default_match = next(
                (m for m in all_models if settings.default_model.lower() in m.name.lower()),
                None
            )

            # 2. Fallback to Qwen if not found
            qwen_match = next((m for m in all_models if "qwen" in m.name.lower()), None)

            model_to_load = default_match or qwen_match or all_models[0]

            log.info(f"Auto-loading model: {model_to_load.name}")
            try:
                await self.load_model(str(model_to_load))
            except Exception as e:
                log.error(f"Auto-load failed for {model_to_load.name}: {e}")
                # Try any other model
                if len(all_models) > 1:
                    other_models = [m for m in all_models if m != model_to_load]
                    await self.load_model(str(other_models[0]))

        return self._is_ready

    async def _download_default_model(self) -> Optional[str]:
        """Download Qwen2.5 1.5B GGUF from Hugging Face."""
        repo_id = "Qwen/Qwen2.5-1.5B-Instruct-GGUF"
        filename = "qwen2.5-1.5b-instruct-q4_k_m.gguf"

        dest = settings.models_dir / "llm" / filename
        dest.parent.mkdir(parents=True, exist_ok=True)

        if dest.exists() and dest.stat().st_size > 500 * 1024 * 1024:
            return str(dest)

        log.info(f"Downloading default model {filename}...")
        try:
            # Try hf or huggingface-cli from venv Scripts
            import os
            venv_bin = Path(settings.base_dir) / ".venv" / ("Scripts" if os.name == "nt" else "bin")
            hf_bin = venv_bin / ("hf.exe" if os.name == "nt" else "hf")
            cli_bin = venv_bin / ("huggingface-cli.exe" if os.name == "nt" else "huggingface-cli")

            executable = str(hf_bin) if hf_bin.exists() else str(cli_bin)

            if hf_bin.exists() or cli_bin.exists():
                log.info(f"Using CLI for download: {executable}")
                env = {**os.environ, "HF_HUB_DISABLE_SYMLINKS": "1"}

                proc = await asyncio.create_subprocess_exec(
                    executable, "download",
                    repo_id,
                    filename,
                    "--local-dir", str(settings.models_dir / "llm"),
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    env=env
                )
                stdout, stderr = await proc.communicate()

                if proc.returncode == 0:
                    log.info("Download complete via CLI", path=str(dest))
                    return str(dest)
                else:
                    log.warning(
                        "CLI download failed, falling back to library",
                        error=stderr.decode()
                    )
            else:
                log.warning("No CLI found in venv, falling back to library")

            # Fallback to library
            path = await asyncio.to_thread(
                hf_hub_download,
                repo_id=repo_id,
                filename=filename,
                local_dir=str(settings.models_dir / "llm"),
                local_dir_use_symlinks=False
            )
            log.info("Download complete via library", path=path)
            return path
        except Exception as e:
            log.error("HF Download failed", error=str(e))
            return None

    async def _try_connect_server(self) -> bool:
        """Try to connect to a running OpenAI-compatible server and verify model availability."""
        try:
            from openai import AsyncOpenAI
            client = AsyncOpenAI(
                base_url=settings.llm_server_url,
                api_key="not-needed",
            )
            # Verify connectivity and model availability
            models_page = await asyncio.wait_for(client.models.list(), timeout=2.0)
            model_list = []
            async for m in models_page:
                model_list.append(m)

            if model_list:
                # Some servers (like LM Studio) might have the server running but no model loaded
                # We try a very short completion to verify it's actually working
                try:
                    await asyncio.wait_for(
                        client.chat.completions.create(
                            model=model_list[0].id,
                            messages=[{"role": "user", "content": "hi"}],
                            max_tokens=1
                        ),
                        timeout=3.0
                    )
                    self._client = client
                    self._current_model = model_list[0].id
                    self._is_ready = True
                    self._server_running = True
                    log.info(
                        "Successfully connected to active LLM server",
                        model=self._current_model
                    )
                    return True
                except Exception as e:
                    log.warning(
                        "LLM server responded but failed to generate completion. "
                        "Might have no model loaded.",
                        error=str(e)
                    )
            else:
                log.warning("LLM server found but no models are available.")
        except Exception as e:
            log.debug("No existing LLM server found or connection failed", error=str(e))
        return False

    # ── Model loading ─────────────────────────────────────────────────────────

    async def load_model(
        self, model_path: str, n_ctx: int = 4096, n_gpu_layers: int = -1,
        n_threads: Optional[int] = None, n_batch: int = 512,
        quantization: int = 0  # 0=None, 4=4bit, 8=8bit
    ):
        async with self._lock:
            # Explicitly unload previous model to free VRAM
            if self._llm:
                log.info(f"Unloading previous model: {self._current_model}")
                del self._llm
                self._llm = None
                self._tokenizer = None
                self._is_ready = False

            log.info(f"Loading model: {model_path} (quant={quantization}bit)")
            
            # Detect model type
            p = Path(model_path)
            if p.is_dir() or (p.suffix not in ['.gguf', '.litertlm', '.tflite', '.task']):
                self._model_type = 'transformers'
                await self._load_transformers_model(model_path, quantization)
            else:
                self._model_type = 'gguf'
                await self._load_gguf_model(model_path, n_ctx, n_gpu_layers, n_threads, n_batch)

    async def _load_transformers_model(self, model_path: str, quantization: int):
        try:
            import torch
            from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
            
            device = "cuda" if torch.cuda.is_available() else "cpu"
            log.info(f"Loading transformers model on {device}")
            
            bnb_config = None
            if quantization == 4:
                bnb_config = BitsAndBytesConfig(
                    load_in_4bit=True,
                    bnb_4bit_compute_dtype=torch.float16,
                    bnb_4bit_quant_type="nf4",
                    bnb_4bit_use_double_quant=True,
                )
            elif quantization == 8:
                bnb_config = BitsAndBytesConfig(load_in_8bit=True)

            def load():
                tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
                model = AutoModelForCausalLM.from_pretrained(
                    model_path,
                    quantization_config=bnb_config,
                    device_map="auto" if device == "cuda" else None,
                    torch_dtype=torch.float16 if device == "cuda" else torch.float32,
                    trust_remote_code=True
                )
                if device == "cpu":
                    model = model.to("cpu")
                return model, tokenizer

            self._llm, self._tokenizer = await asyncio.get_event_loop().run_in_executor(
                None, load
            )
            self._current_model = Path(model_path).name
            self._current_model_path = model_path
            self._is_ready = True
            log.info(f"Transformers model loaded: {self._current_model}")
        except Exception as e:
            log.error(f"Failed to load transformers model: {e}")
            self._llm = None
            self._tokenizer = None
            raise

    async def _load_gguf_model(
        self, model_path: str, n_ctx: int = 4096, n_gpu_layers: int = -1,
        n_threads: Optional[int] = None, n_batch: int = 512
    ):
            try:
                import llama_cpp
                from llama_cpp import Llama

                def init_llama(use_gpu=True):
                    # Restore CUDA visibility
                    import os
                    if "CUDA_VISIBLE_DEVICES" in os.environ:
                        del os.environ["CUDA_VISIBLE_DEVICES"]

                    # Optimization for speed on high-core systems
                    cpu_cores = multiprocessing.cpu_count()
                    threads = n_threads or min(8, max(4, cpu_cores // 2))

                    # Full offload for maximum speed (now safe due to serialization lock)
                    gpu_layers = -1 if use_gpu else 0

                    # Safe context window for Qwen 1.5B
                    context_size = 4096

                    log.info(
                        f"HIGH SPEED RESTORE: GPU={use_gpu}, threads={threads}, ctx={context_size}"
                    )

                    llm = Llama(
                        model_path=model_path,
                        n_ctx=context_size,
                        n_gpu_layers=gpu_layers,
                        n_threads=threads,
                        n_threads_batch=threads,
                        n_batch=512,                 # Restore fast batching
                        flash_attn=False,
                        use_mmap=False,
                        use_mlock=False,
                        logits_all=False,
                        verbose=False,
                        chat_format="chatml",
                    )
                    return llm, gpu_layers

                try:
                    self._llm, actual_gpu_layers = await asyncio.get_event_loop().run_in_executor(
                        None, lambda: init_llama(use_gpu=True)
                    )
                except Exception as e:
                    log.warning(f"GPU load failed, retrying on CPU: {e}")
                    self._llm, actual_gpu_layers = await asyncio.get_event_loop().run_in_executor(
                        None, lambda: init_llama(use_gpu=False)
                    )

                self._current_model = Path(model_path).stem
                self._current_model_path = model_path
                self._is_ready = True

                # Verify CUDA status and log configuration
                cuda_supported = llama_cpp.llama_supports_gpu_offload()
                log.info(
                    f"Model loaded: {self._current_model}",
                    cuda_supported=cuda_supported,
                    n_ctx=4096,
                    n_gpu_layers=actual_gpu_layers if cuda_supported else 0
                )
            except ImportError:
                log.error("llama-cpp-python not installed. See SETUP.md.")
                self._llm = None
            except Exception as e:
                log.error(f"Failed to load model: {e}")
                self._llm = None

    async def unload_model(self):
        async with self._lock:
            if self._llm:
                del self._llm
                self._llm = None
            self._current_model = None
            self._current_model_path = None
            self._is_ready = False
            log.info("Model unloaded")

    # ── Streaming chat ────────────────────────────────────────────────────────

    async def stream_chat(
        self,
        messages: list[dict],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> AsyncIterator[str]:
        self._interrupt_chat = False  # Reset interrupt flag
        if model == "Auto":
            model = None

        use_direct = self._llm is not None and (not model or model == self._current_model)

        if use_direct:
            if self._model_type == 'gguf':
                async for tok in self._stream_direct_gguf(messages, temperature, max_tokens):
                    yield tok
            else:
                async for tok in self._stream_direct_transformers(messages, temperature, max_tokens):
                    yield tok
        elif self._client:
            async for tok in self._stream_via_server(messages, model, temperature, max_tokens):
                yield tok
        else:
            yield "⚠️ No LLM loaded. Please load a model in the Models tab."

    async def _stream_via_server(
        self, messages, model, temperature, max_tokens
    ) -> AsyncIterator[str]:
        """openai 2.x streaming — async context manager pattern."""
        try:
            async with self._client.chat.completions.stream(
                model=model or self._current_model or "local-model",
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            ) as stream:
                async for event in stream:
                    # openai 2.x: event.type == "content.delta" carries text
                    if hasattr(event, "type") and event.type == "content.delta":
                        if hasattr(event, "delta") and event.delta:
                            yield event.delta
                    # Fallback: old-style chunk with choices[0].delta.content
                    elif hasattr(event, "choices"):
                        delta = event.choices[0].delta.content if event.choices else None
                        if delta:
                            yield delta
        except AttributeError:
            # openai 2.x also supports create() with stream=True as context manager
            try:
                stream = await self._client.chat.completions.create(
                    model=model or self._current_model or "local-model",
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    stream=True,
                )
                async for chunk in stream:
                    if chunk.choices and chunk.choices[0].delta.content:
                        yield chunk.choices[0].delta.content
            except Exception as e:
                yield f"\n\n❌ Stream error: {e}"
        except Exception as e:
            yield f"\n\n❌ Stream error: {e}"

    async def _stream_direct_transformers(self, messages, temperature, max_tokens) -> AsyncIterator[str]:
        """HF Transformers direct inference."""
        from transformers import TextIteratorStreamer
        import torch
        
        # Build prompt from messages
        prompt = ""
        for m in messages:
            role = m["role"]
            content = m["content"]
            if role == "system":
                prompt += f"<|im_start|>system\n{content}<|im_end|>\n"
            elif role == "user":
                prompt += f"<|im_start|>user\n{content}<|im_end|>\n"
            elif role == "assistant":
                prompt += f"<|im_start|>assistant\n{content}<|im_end|>\n"
        prompt += "<|im_start|>assistant\n"

        inputs = self._tokenizer(prompt, return_tensors="pt").to(self._llm.device)
        streamer = TextIteratorStreamer(self._tokenizer, skip_prompt=True, skip_special_tokens=True)
        
        def generate():
            with torch.no_grad():
                self._llm.generate(
                    **inputs,
                    streamer=streamer,
                    max_new_tokens=max_tokens,
                    temperature=temperature,
                    do_sample=temperature > 0,
                    pad_token_id=self._tokenizer.eos_token_id
                )

        loop = asyncio.get_event_loop()
        loop.run_in_executor(None, generate)

        for text in streamer:
            if self._interrupt_chat:
                break
            yield text

    async def _stream_direct_gguf(self, messages, temperature, max_tokens) -> AsyncIterator[str]:
        """llama-cpp-python direct inference — runs in thread pool."""
        loop = asyncio.get_event_loop()
        queue: asyncio.Queue = asyncio.Queue()

        def run():
            try:
                # Serialization lock to prevent concurrent CUDA access
                with self._inference_lock:
                    log.debug("Sending messages to Llama", count=len(messages))
                    # Log last message for context
                    if messages:
                        log.debug("Chat", r=messages[-1]["role"], c=messages[-1]["content"][:20])

                    stream = self._llm.create_chat_completion(
                        messages=messages,
                        temperature=temperature,
                        max_tokens=max_tokens,
                        stream=True,
                        stop=["<|im_end|>", "<|endoftext|>"],
                        repeat_penalty=1.1,
                        top_p=0.9,
                        top_k=40,
                    )

                    token_count = 0
                    for chunk in stream:
                        if self._interrupt_chat:
                            log.info("Inference interrupted")
                            break
                        delta = chunk["choices"][0]["delta"].get("content", "")
                        if delta:
                            token_count += 1
                            if token_count % 10 == 0:
                                log.debug(f"Generated {token_count} tokens...")
                            loop.call_soon_threadsafe(queue.put_nowait, delta)

                    log.debug("Stream finished", total_tokens=token_count)
                    loop.call_soon_threadsafe(queue.put_nowait, None)
            except Exception as e:
                log.error("Inference thread crashed", error=str(e))
                loop.call_soon_threadsafe(queue.put_nowait, Exception(str(e)))

        loop.run_in_executor(None, run)

        while True:
            item = await queue.get()
            if item is None:
                break
            if isinstance(item, Exception):
                yield f"\n\n❌ Inference error: {item}"
                break
            yield item

    def interrupt(self):
        """Stop current inference loop."""
        self._interrupt_chat = True
        log.info("LLM inference interrupted")

    # ── Non-streaming complete ─────────────────────────────────────────────────

    async def complete(
        self,
        prompt: str,
        temperature: float = 0.2,
        max_tokens: int = 1024,
    ) -> str:
        result = []
        async for token in self.stream_chat(
            [{"role": "user", "content": prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
        ):
            result.append(token)
        return "".join(result)

    # ── Server management ─────────────────────────────────────────────────────

    async def start_server(self, model_path: Optional[str] = None,
                           port: Optional[int] = None, host: str = "127.0.0.1"):
        path = model_path or self._current_model_path
        srv_port = port or settings.llm_server_port
        srv_host = host or settings.llm_server_host

        if self._server_running or not path:
            return
        try:
            threads = max(1, multiprocessing.cpu_count() - 1)
            threads_batch = max(1, multiprocessing.cpu_count())
            self._server_process = await asyncio.create_subprocess_exec(
                "llama-server",
                "--model", path,
                "--host", srv_host,
                "--port", str(srv_port),
                "--ctx-size", str(settings.context_length),
                "--n-gpu-layers", str(settings.n_gpu_layers),
                "--threads", str(threads),
                "--threads-batch", str(threads_batch),
                "--batch-size", "2048",
                "--mlock",
                "--flash-attn",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            self._server_running = True

            # Update settings temporarily for current session if port changed
            settings.llm_server_port = srv_port
            settings.llm_server_url = f"http://{srv_host}:{srv_port}/v1"

            await asyncio.sleep(2)
            await self._try_connect_server()
            log.info(f"LLM server started on port {srv_port} with model {Path(path).name}")
        except FileNotFoundError:
            log.error("llama-server not found")

    async def stop_server(self):
        if self._server_process:
            self._server_process.terminate()
            await self._server_process.wait()
            self._server_process = None
        self._server_running = False
        self._client = None

    async def cleanup(self):
        await self.stop_server()
        await self.unload_model()
