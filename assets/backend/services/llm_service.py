import os
import asyncio
import multiprocessing
import structlog
from pathlib import Path
from typing import AsyncIterator, Optional, AsyncIterator

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
        _x64_path = _bin_path / "x64"
        if _x64_path.exists():
            try:
                os.add_dll_directory(str(_x64_path))
            except Exception:
                pass
        elif _bin_path.exists():
            try:
                os.add_dll_directory(str(_bin_path))
            except Exception:
                pass

    # 3. Try llama-cpp-python lib directory (essential for bundled DLLs)
    try:
        # Check standard venv location first
        _venv_llama_lib = Path(os.getcwd()) / ".venv" / "Lib" / "site-packages" / "llama_cpp" / "lib"
        if _venv_llama_lib.exists():
            os.add_dll_directory(str(_venv_llama_lib))
        
        # Fallback to importing (if it doesn't crash)
        import llama_cpp
        _llama_lib = Path(llama_cpp.__file__).parent / "lib"
        if _llama_lib.exists() and str(_llama_lib) != str(_venv_llama_lib):
            os.add_dll_directory(str(_llama_lib))
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
        
        # New: Support for vision/multimodal if needed
        self._mmproj_path: Optional[str] = None

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

    @property
    def mmproj_path(self) -> Optional[str]:
        return self._mmproj_path

    @property
    def supports_vision(self) -> bool:
        return self._mmproj_path is not None

    # ── Startup ──────────────────────────────────────────────────────────────

    async def initialize(self) -> bool:
        """Initialize the LLM service — Local Gemma-4 first, then fallback to discovery/server."""
        self._is_ready = False
        self._current_model = None
        self._current_model_path = None

        # ── Priority 1: Hard-coded Gemma-4 directory ──────────────────────────
        gemma4_dir = settings.models_dir / "llm" / "gemma-4-E4B-it-GGUF"
        if gemma4_dir.exists():
            chat_models = [f for f in gemma4_dir.glob("*.gguf")
                           if not any(x in f.name.lower() for x in ["mmproj", "clip", "projector"])]
            if chat_models:
                model_to_load = chat_models[0]
                log.info(f"Auto-loading Gemma-4: {model_to_load.name}")
                try:
                    # Use load_model for robust auto-detection of mmproj and format
                    await self.load_model(str(model_to_load.resolve()))
                    if self._is_ready:
                        return True
                except Exception as e:
                    log.error(f"Gemma-4 auto-load failed: {e}")

        # ── Priority 2: External Server Fallback ──────────────────────────────
        if await self._try_connect_server():
            log.info("Connected to existing LLM server", url=settings.llm_server_url)
            return True

        # ── Priority 3: Generic local discovery ──────────────────────────────
        all_files = list(settings.models_dir.rglob("*.gguf"))
        all_models = [f for f in all_files if not any(x in f.name.lower() for x in ["mmproj", "clip", "projector"])]

        if not all_models:
            log.info("No LLM models found. Downloading default...")
            try:
                model_path = await self._download_default_model()
                if model_path:
                    await self.load_model(model_path)
            except Exception as e:
                log.error(f"Failed to download default model: {e}")
        else:
            default_match = next(
                (m for m in all_models if settings.default_model.lower() in m.name.lower()), None
            )
            instruct_match = next((m for m in all_models if any(x in m.name.lower() for x in ["instruct", "-it-", "chat"])), None)
            model_to_load = default_match or instruct_match or all_models[0]

            log.info(f"Auto-loading model: {model_to_load.name}")
            try:
                proj_files = [f for f in all_files if any(x in f.name.lower() for x in ["mmproj", "clip", "projector"])]
                mmproj_path = None
                if proj_files:
                    match = next((p for p in proj_files if model_to_load.stem.lower() in p.name.lower()), proj_files[0])
                    mmproj_path = str(match.resolve())
                await self.load_model(str(model_to_load), mmproj_path=mmproj_path)
            except Exception as e:
                log.error(f"Auto-load failed for {model_to_load.name}: {e}")
                remaining = [m for m in all_models if m != model_to_load]
                if remaining:
                    await self.load_model(str(remaining[0]))

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
            models_page = await asyncio.wait_for(client.models.list(), timeout=10.0)
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
                        timeout=5.0
                    )
                except Exception as e:
                    log.warning(
                        "LLM server responded but failed to generate completion (timeout or error). "
                        "Assuming model is loaded anyway for slow visual models.",
                        error=str(e)
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
            else:
                log.warning("LLM server found but no models are available.")
        except Exception as e:
            log.warning("LLM server connection failed", error=str(e), url=settings.llm_server_url)
        return False

    # ── Model loading ─────────────────────────────────────────────────────────

    async def load_model(
        self, model_path: str, n_ctx: Optional[int] = None, n_gpu_layers: int = -1,
        n_threads: Optional[int] = None, n_batch: int = 512,
        quantization: int = 0, mmproj_path: Optional[str] = None
    ):
        async with self._lock:
            if n_ctx is None:
                n_ctx = settings.context_length

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
                await self._load_gguf_model(model_path, n_ctx, n_gpu_layers, n_threads, n_batch, mmproj_path)

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
        self, model_path: str, n_ctx: int = 8192, n_gpu_layers: int = -1,
        n_threads: Optional[int] = None, n_batch: int = 512,
        mmproj_path: Optional[str] = None
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

                    # Full GPU offload for maximum speed if requested
                    gpu_layers = n_gpu_layers if n_gpu_layers >= 0 else (-1 if use_gpu else 0)

                    # Use the requested context size (not hardcoded)
                    context_size = n_ctx

                    # Optimized batch size for RTX 5060/4060 (8GB VRAM)
                    # 1024 allows much faster prompt processing (TTFT) for RAG contexts
                    batch_size = 1024

                    log.info(
                        f"LLM CONFIG: gpu_layers={gpu_layers}, threads={threads}, "
                        f"ctx={context_size}, n_batch={batch_size}"
                    )

                    # Vision support via chat handler
                    actual_mmproj = mmproj_path
                    if not actual_mmproj:
                        # Auto-detect projector in the same directory as the model
                        # Auto-detect projector: search model dir, then global models dir
                        model_dir = Path(model_path).parent
                        log.info(f"Scanning for vision projector in: {model_dir}")
                        
                        patterns = ["*mmproj*.gguf", "*clip*.gguf"]
                        proj_files = []
                        for pat in patterns:
                            proj_files.extend(list(model_dir.rglob(pat)))
                        
                        if not proj_files:
                            log.info(f"Projector not found in model dir, searching global models dir: {settings.models_dir}")
                            for pat in patterns:
                                proj_files.extend(list(settings.models_dir.rglob(pat)))
                        
                        # Filter out directories and keep unique paths
                        proj_files = list(set([f.resolve() for f in proj_files if f.is_file()]))
                        
                        if proj_files:
                            actual_mmproj = str(proj_files[0])
                            log.info(f"Auto-detected vision projector: {Path(actual_mmproj).name}")

                    chat_handler = None
                    if actual_mmproj:
                        try:
                            from llama_cpp.llama_chat_format import Llava15ChatHandler
                            
                            is_gemma = "gemma" in model_path.lower()
                            
                            if is_gemma:
                                class GemmaVisionChatHandler(Llava15ChatHandler):
                                    CHAT_FORMAT = (
                                        "{% for message in messages %}"
                                        "{% if message.role == 'system' %}<start_of_turn>system\n{{ message.content }}<end_of_turn>\n{% endif %}"
                                        "{% if message.role == 'user' %}<start_of_turn>user\n"
                                        "{% if message.content is string %}{{ message.content }}"
                                        "{% else %}"
                                        "{% for content in message.content %}"
                                        "{% if content.type == 'image_url' and content.image_url is string %}{{ content.image_url }}\n{% endif %}"
                                        "{% if content.type == 'image_url' and content.image_url is mapping %}{{ content.image_url.url }}\n{% endif %}"
                                        "{% endfor %}"
                                        "{% for content in message.content %}"
                                        "{% if content.type == 'text' %}{{ content.text }}{% endif %}"
                                        "{% endfor %}"
                                        "{% endif %}"
                                        "<end_of_turn>\n{% endif %}"
                                        "{% if message.role == 'assistant' and message.content is not none %}<start_of_turn>model\n{{ message.content }}<end_of_turn>\n{% endif %}"
                                        "{% endfor %}"
                                        "{% if add_generation_prompt %}<start_of_turn>model\n{% endif %}"
                                    )
                                chat_handler = GemmaVisionChatHandler(clip_model_path=actual_mmproj, verbose=False)
                                log.info(f"Vision projector active: {Path(actual_mmproj).name} (Gemma format)")
                            else:
                                chat_handler = Llava15ChatHandler(clip_model_path=actual_mmproj, verbose=False)
                                log.info(f"Vision projector active: {Path(actual_mmproj).name}")
                        except Exception as e:
                            log.warning(f"Failed to load vision projector: {e}")

                    # Intelligent chat format detection
                    fmt = "chatml"
                    is_gemma = "gemma" in model_path.lower()
                    if actual_mmproj:
                        fmt = "gemma" if is_gemma else "llava-1-5"
                    elif is_gemma:
                        fmt = "gemma"
                    elif "llama-3" in model_path.lower():
                        fmt = "llama-3"

                    llm = Llama(
                        model_path=model_path,
                        n_ctx=context_size,
                        n_gpu_layers=gpu_layers,
                        n_threads=threads,
                        n_threads_batch=threads,
                        n_batch=batch_size,
                        n_ubatch=batch_size,  # Match batch size for maximum GPU saturation during image eval
                        flash_attn=gpu_layers != 0,
                        use_mmap=True,
                        use_mlock=False,
                        offload_kqv=gpu_layers != 0,  # Offload KV cache to GPU
                        type_k=8,  # Q8_0 KV cache quantization (saves VRAM, prevents CPU fallback)
                        type_v=8,  # Q8_0 KV cache quantization
                        logits_all=False,
                        verbose=False,
                        chat_format=fmt,
                        chat_handler=chat_handler,
                    )
                    return llm, gpu_layers, actual_mmproj

                try:
                    self._llm, actual_gpu_layers, final_mmproj = await asyncio.get_event_loop().run_in_executor(
                        None, lambda: init_llama(use_gpu=True)
                    )
                except Exception as e:
                    log.warning(f"GPU load failed, retrying on CPU: {e}")
                    self._llm, actual_gpu_layers, final_mmproj = await asyncio.get_event_loop().run_in_executor(
                        None, lambda: init_llama(use_gpu=False)
                    )

                self._current_model = Path(model_path).stem
                self._current_model_path = model_path
                self._mmproj_path = final_mmproj
                self._is_ready = True

                # Verify CUDA status and log configuration
                cuda_supported = llama_cpp.llama_supports_gpu_offload()
                log.info(
                    f"Model loaded: {self._current_model}",
                    cuda_supported=cuda_supported,
                    n_ctx=n_ctx,
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
        # If we are currently loading a model, wait for it
        if self._lock.locked():
            log.info("Chat requested while model is loading, waiting...")
            async with self._lock:
                pass # Just wait for the lock to release

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
            yield "⚠️ No LLM loaded and no server connected. Please load a model in the Models tab."

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
                    
                    # 1. Clean history: Strip images from past turns, only keep current image
                    clean_messages = []
                    has_images = False
                    
                    for idx, msg in enumerate(messages):
                        if isinstance(msg.get("content"), list):
                            new_content = []
                            for part in msg["content"]:
                                if isinstance(part, dict) and part.get("type") == "image_url":
                                    # Only evaluate image if it's in the very last message
                                    if idx == len(messages) - 1:
                                        new_content.append(part)
                                        has_images = True
                                    else:
                                        # Replace old images with a lightweight text marker
                                        new_content.append({"type": "text", "text": "[Image uploaded in previous turn]"})
                                else:
                                    new_content.append(part)
                                    
                            # If all parts are text, flatten to string to prevent format handler confusion
                            if all(isinstance(p, dict) and p.get("type") == "text" for p in new_content):
                                text_only = "\n".join(p.get("text", "") for p in new_content)
                                clean_messages.append({"role": msg["role"], "content": text_only})
                            else:
                                clean_messages.append({"role": msg["role"], "content": new_content})
                        else:
                            clean_messages.append(msg)

                    if clean_messages:
                        log.debug("Chat", r=clean_messages[-1]["role"], c=str(clean_messages[-1]["content"])[:50])

                    # 2. Prevent Llava15ChatHandler from resetting KV cache on text queries
                    original_handler = getattr(self._llm, "chat_handler", None)
                    if not has_images and original_handler is not None:
                        self._llm.chat_handler = None
                        log.debug("Disabled vision handler for text-only query (preserves KV cache)")

                    try:
                        stream = self._llm.create_chat_completion(
                            messages=clean_messages,
                            temperature=temperature,
                            max_tokens=max_tokens,
                            stream=True,
                            stop=["<|im_end|>", "<|endoftext|>", "<end_of_turn>", "<eos>", "<|eot_id|>", "<|end_of_text|>"],
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
                    finally:
                        # 3. Restore the vision handler for future image uploads
                        if not has_images and original_handler is not None:
                            self._llm.chat_handler = original_handler

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

    # ── Multimodal streaming ──────────────────────────────────────────────────

    async def stream_chat_multimodal(
        self,
        text_prompt: str,
        image_paths: list[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> AsyncIterator[str]:
        """
        Stream a multimodal chat response.
        - If vision projector (mmproj) is loaded and image_paths provided,
          uses LLaVA-style image+text message format.
        - Otherwise falls back to plain text streaming.
        """
        self._interrupt_chat = False
        image_paths = image_paths or []

        # Build multimodal message if images provided and vision supported
        if image_paths and self._llm is not None and self._mmproj_path:
            messages = await self._build_vision_messages(text_prompt, image_paths)
            async for tok in self._stream_direct_gguf(messages, temperature, max_tokens):
                yield tok
        elif self._client:
            # Server-side multimodal (e.g. LM Studio with vision model)
            # Build OpenAI-style multimodal messages
            mm_messages = await self._build_vision_messages(text_prompt, image_paths)
            async for tok in self._stream_via_server(
                mm_messages,
                None, temperature, max_tokens
            ):
                yield tok
        elif self._llm is not None:
            # Plain text fallback if no vision projector
            async for tok in self._stream_direct_gguf(
                [{"role": "user", "content": text_prompt}],
                temperature, max_tokens
            ):
                yield tok
        else:
            yield "⚠️ No LLM loaded. Please load a model in the Models tab."

    async def _build_vision_messages(self, prompt: str, image_paths: list[str]) -> list[dict]:
        """Build LLaVA-style message list with base64-encoded images."""
        import base64

        content_parts = []
        for img_path in image_paths:
            try:
                path = Path(img_path)
                if not path.exists():
                    continue
                ext = path.suffix.lower().lstrip('.')
                mime = {
                    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
                    'png': 'image/png', 'gif': 'image/gif',
                    'webp': 'image/webp', 'bmp': 'image/bmp',
                }.get(ext, 'image/jpeg')

                with open(img_path, 'rb') as f:
                    b64 = base64.b64encode(f.read()).decode('utf-8')

                content_parts.append({
                    'type': 'image_url',
                    'image_url': {'url': f'data:{mime};base64,{b64}'},
                })
            except Exception as e:
                log.warning(f"Failed to encode image {img_path}: {e}")

        content_parts.append({'type': 'text', 'text': prompt})

        return [{'role': 'user', 'content': content_parts}]

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
