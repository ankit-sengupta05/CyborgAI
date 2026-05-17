"""
Models API — LM Studio-compatible endpoints for local model management.
"""
import asyncio
import structlog
from fastapi import APIRouter, Request, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
from pathlib import Path

from services.llm_service import LLMService
from config.settings import settings

log = structlog.get_logger(__name__)
router = APIRouter()

# ── LM Studio model scanner ───────────────────────────────────────────────────

def _scan_lmstudio_models() -> list[dict]:
    """
    Scan LM Studio's model directory recursively and group by folder.
    """
    lmstudio_dir = settings.lmstudio_models_dir
    results: list[dict] = []

    if not lmstudio_dir.exists():
        return results

    try:
        dir_to_files: dict[Path, list[Path]] = {}
        for gguf_path in lmstudio_dir.rglob("*.gguf"):
            parent = gguf_path.parent
            if parent not in dir_to_files:
                dir_to_files[parent] = []
            dir_to_files[parent].append(gguf_path)

        for model_dir, files in dir_to_files.items():
            mmproj_files = [f for f in files if settings.mmproj_suffix in f.name.lower()]
            main_files = [f for f in files if settings.mmproj_suffix not in f.name.lower()]

            if not main_files:
                continue

            # Pick largest GGUF as primary
            main_file = max(main_files, key=lambda f: f.stat().st_size)
            mmproj_path = str(mmproj_files[0]) if mmproj_files else None

            # Display metadata
            rel_parts = main_file.relative_to(lmstudio_dir).parts
            publisher = rel_parts[0] if len(rel_parts) > 1 else "unknown"
            
            # Use folder name for ID/Display if nested enough
            if len(rel_parts) > 2:
                model_family = rel_parts[1]
                model_id = f"lmstudio-{model_family.lower()}"
                display_name = model_family
            else:
                model_id = f"lmstudio-{main_file.stem.lower()}"
                display_name = main_file.stem

            total_size = sum(f.stat().st_size for f in files)

            results.append({
                "id": model_id,
                "name": f"{display_name} ({publisher})",
                "publisher": publisher,
                "model_family": display_name,
                "size_gb": round(total_size / (1024 ** 3), 2),
                "quantization": "GGUF",
                "task_type": "text-generation",
                "path": str(main_file),
                "mmproj_path": mmproj_path,
                "downloaded": True,
                "loaded": False,
                "source": "lmstudio",
                "supports_vision": mmproj_path is not None,
            })
    except Exception as e:
        log.warning(f"LM Studio scan error: {e}")

    return results

# Model catalog for browsing
MODEL_CATALOG = [
    {
        "id": "gemma-4-e2b-it-q8-0", "name": "Gemma 4 E2B (Recommended)", "size_gb": 4.6,
        "quantization": "Q8_0", "task_type": "text-generation", "rating": 5.0, "downloads": 1000,
        "hf_repo": "google/gemma-2-2b-it-GGUF"  # Fallback repo
    },
    {
        "id": "qwen2.5-1.5b-instruct-q4", "name": "Qwen2.5 1.5B Instruct", "size_gb": 1.1,
        "quantization": "Q4_K_M", "task_type": "instruct", "rating": 4.8, "downloads": 56000,
        "hf_repo": "Qwen/Qwen2.5-1.5B-Instruct-GGUF"
    },
    {
        "id": "qwen2.5-coder-14b-q4", "name": "Qwen2.5-Coder 14B", "size_gb": 8.4,
        "quantization": "Q4_K_M", "task_type": "code", "rating": 4.9, "downloads": 124000,
        "hf_repo": "Qwen/Qwen2.5-Coder-14B-Instruct-GGUF"
    },
    {
        "id": "llama-3.2-8b-q4", "name": "Llama 3.2 8B", "size_gb": 4.7,
        "quantization": "Q4_K_M", "task_type": "text-generation", "rating": 4.7, "downloads": 98000,
        "hf_repo": "meta-llama/Llama-3.2-8B-Instruct-GGUF"
    },
    {
        "id": "mistral-7b-q4", "name": "Mistral 7B Instruct", "size_gb": 4.1,
        "quantization": "Q4_K_M", "task_type": "instruct", "rating": 4.6, "downloads": 89000,
        "hf_repo": "TheBloke/Mistral-7B-Instruct-v0.2-GGUF"
    },
    {
        "id": "phi-3.5-mini-q4", "name": "Phi-3.5 Mini", "size_gb": 2.2,
        "quantization": "Q4_K_M", "task_type": "text-generation", "rating": 4.5, "downloads": 45000,
        "hf_repo": "microsoft/Phi-3.5-mini-instruct-gguf"
    },
    {
        "id": "deepseek-r1-7b-q4", "name": "DeepSeek-R1 7B", "size_gb": 4.7,
        "quantization": "Q4_K_M", "task_type": "reasoning", "rating": 4.8, "downloads": 67000,
        "hf_repo": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B-GGUF"
    },
    {
        "id": "gemma2-9b-q4", "name": "Gemma 2 9B", "size_gb": 5.4,
        "quantization": "Q4_K_M", "task_type": "text-generation", "rating": 4.6, "downloads": 52000,
        "hf_repo": "google/gemma-2-9b-it-GGUF"
    },
    {
        "id": "codestral-22b-q4", "name": "Codestral 22B", "size_gb": 12.4,
        "quantization": "Q4_K_M", "task_type": "code", "rating": 4.8, "downloads": 38000,
        "hf_repo": "bartowski/Codestral-22B-v0.1-GGUF"
    },
    {
        "id": "moondream2", "name": "Moondream2 (Vision)", "size_gb": 1.8,
        "quantization": "Q8", "task_type": "vision", "rating": 4.4, "downloads": 29000,
        "hf_repo": "vikhyatk/moondream2"
    },
    {
        "id": "gemma4-2b-litert", "name": "Gemma 4 2B", "size_gb": 1.5,
        "quantization": "LiteRT", "task_type": "text-generation", "rating": 4.9, "downloads": 15000,
        "hf_repo": "litert-community/gemma-4-2b-it-litertlm"
    },
    {
        "id": "medgemma-2-9b-q4", "name": "MedGemma 2 9B (Health Track)", "size_gb": 5.4,
        "quantization": "Q4_K_M", "task_type": "medical", "rating": 5.0, "downloads": 18000,
        "hf_repo": "bartowski/MedGemma-2-9b-it-GGUF"
    },
    {
        "id": "gemma-4-4b-it-q4", "name": "Gemma 4 4B (Education Track)", "size_gb": 2.6,
        "quantization": "Q4_K_M", "task_type": "education", "rating": 4.8, "downloads": 24000,
        "hf_repo": "bartowski/gemma-2-9b-it-GGUF"  # Example repo for education tuning
    },
]


class LoadModelRequest(BaseModel):
    model_id: Optional[str] = None
    n_gpu_layers: int = -1
    n_ctx: int = 4096
    n_threads: Optional[int] = None
    n_batch: int = 2048
    quantization: int = 0
    mmproj_path: Optional[str] = None  # CLIP projector for multimodal models


class LoadCustomModelRequest(BaseModel):
    path: str
    mmproj_path: Optional[str] = None  # Optional mmproj for vision support


class ServerConfigRequest(BaseModel):
    url: str
    host: Optional[str] = None
    port: Optional[int] = None


class StartServerRequest(BaseModel):
    model_path: Optional[str] = None
    port: Optional[int] = None
    host: str = "127.0.0.1"


@router.get("/list")
async def list_downloaded_models(request: Request):
    """List all downloaded models and models from external server if connected."""
    models_dir = settings.models_dir
    downloaded = []
    llm_svc: LLMService = request.app.state.llm_service

    # 1. Local files grouped by directory
    dir_to_files = {}
    for ext in ["*.gguf", "*.litertlm", "*.tflite", "*.bin", "*.task"]:
        for model_file in models_dir.rglob(ext):
            parent_dir = model_file.parent
            if parent_dir not in dir_to_files:
                dir_to_files[parent_dir] = []
            dir_to_files[parent_dir].append(model_file)

    for model_dir, files in dir_to_files.items():
        # Find mmproj
        mmproj_files = [f for f in files if settings.mmproj_suffix in f.name.lower()]
        main_files = [f for f in files if settings.mmproj_suffix not in f.name.lower()]

        if not main_files:
            continue  # Only mmproj in this folder, skip showing it standalone

        # Pick the largest main file as the primary model
        main_file = max(main_files, key=lambda f: f.stat().st_size)
        mmproj_path = str(mmproj_files[0]) if mmproj_files else None

        # Determine name and ID based on folder or file
        if model_dir.name in ["llm", "models", "backend", "assets"]:
            model_id = main_file.stem.lower().replace("_", "-")
            display_name = main_file.stem
        else:
            model_id = model_dir.name.lower().replace("_", "-")
            display_name = model_dir.name

        catalog_entry = next(
            (m for m in MODEL_CATALOG if m["id"].lower() in model_id.lower()
             or model_id.lower() in m["id"].lower()),
            None
        )

        loaded = False
        if hasattr(llm_svc, "current_model_path") and llm_svc.current_model_path:
            current_path = Path(llm_svc.current_model_path).resolve()
            loaded = any(str(current_path) == str(f.resolve()) for f in files)

        total_size = sum(f.stat().st_size for f in files)

        downloaded.append({
            "id": model_id,
            "name": catalog_entry["name"] if catalog_entry else display_name,
            "size_gb": round(total_size / (1024**3), 2),
            "quantization": catalog_entry["quantization"] if catalog_entry else (
                "LiteRT" if main_file.suffix in [".litertlm", ".tflite", ".task"]
                else "GGUF"
            ),
            "task_type": catalog_entry["task_type"] if catalog_entry else ("vision" if mmproj_path else "text-generation"),
            "path": str(main_file),
            "mmproj_path": mmproj_path,
            "supports_vision": mmproj_path is not None,
            "downloaded": True,
            "loaded": loaded,
            "source": "local"
        })

    # 3. LM Studio models
    lmstudio_models = await asyncio.to_thread(_scan_lmstudio_models)
    for lm_model in lmstudio_models:
        # Mark as loaded if path matches
        if hasattr(llm_svc, "current_model_path") and llm_svc.current_model_path:
            lm_model["loaded"] = (
                str(Path(llm_svc.current_model_path).resolve()) ==
                str(Path(lm_model["path"]).resolve())
            )
        # Only add if not already present (avoid duplicates with local copies)
        if not any(d["path"] == lm_model["path"] for d in downloaded):
            downloaded.append(lm_model)

    # 4. External server models
    if llm_svc._client:
        try:
            models_page = await asyncio.wait_for(llm_svc._client.models.list(), timeout=1.0)
            async for m in models_page:
                # Check if already in list (some might be local and served)
                if any(d["id"] == m.id or d["name"] == m.id for d in downloaded):
                    continue

                downloaded.append({
                    "id": m.id,
                    "name": f"{m.id} (External)",
                    "size_gb": 0,
                    "quantization": "External",
                    "task_type": "text-generation",
                    "path": m.id,
                    "downloaded": True,
                    "loaded": llm_svc.current_model == m.id,
                    "source": "external"
                })
        except Exception:
            pass

    return {"models": downloaded}


@router.get("/search")
async def search_models(q: str = "", task: str = ""):
    """Search the model catalog."""
    results = MODEL_CATALOG
    if q:
        results = [m for m in results
                   if q.lower() in m["name"].lower() or q.lower() in m["id"]]
    if task:
        results = [m for m in results if task.lower() in m["task_type"]]
    return {"models": results, "total": len(results)}


@router.post("/download/{model_id:path}")
async def download_model(model_id: str, background_tasks: BackgroundTasks, request: Request):
    """Start downloading a model from Hugging Face catalog."""
    catalog_entry = next((m for m in MODEL_CATALOG if m["id"] == model_id), None)
    if not catalog_entry:
        # If not in catalog, try to use it as a repo ID (fallback)
        return await download_repo_model(
            model_id.replace("--", "/"),
            background_tasks=background_tasks,
            request=request
        )

    background_tasks.add_task(_download_model_task, catalog_entry, request.app.state)
    return {"status": "downloading", "model_id": model_id, "size_gb": catalog_entry["size_gb"]}


@router.post("/download/repo")
async def download_repo_model(
    repo_id: str,
    filename: Optional[str] = None,
    background_tasks: BackgroundTasks = None,
    request: Request = None
):
    """Download any GGUF model from Hugging Face by repo ID."""
    info = {
        "id": repo_id.replace("/", "--"),
        "name": repo_id.split("/")[-1],
        "hf_repo": repo_id,
        "filename": filename,
        "size_gb": 0
    }
    background_tasks.add_task(_download_model_task, info, request.app.state)
    return {"status": "downloading", "repo_id": repo_id}


async def _download_model_task(model_info: dict, app_state):
    """Background task to download a model."""
    import os

    models_dir = settings.models_dir
    model_dir = models_dir / model_info["id"]
    model_dir.mkdir(exist_ok=True)

    log.info(f"Starting download: {model_info['name']}")
    try:
        # Use huggingface-hub CLI for downloading
        env = {**os.environ, "HF_HOME": str(settings.cache_dir / "huggingface")}
        args = [
            "huggingface-cli", "download",
            model_info["hf_repo"],
            "--local-dir", str(model_dir),
        ]
        if model_info.get("filename"):
            args.extend(["--include", model_info["filename"]])
        else:
            args.extend([
                "--include", "*.gguf",
                "--include", "*.litertlm",
                "--include", "*.tflite",
                "--include", "*.task",
                "--include", "*.bin",
            ])

        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            env=env,
        )
        stdout, stderr = await proc.communicate()
        if proc.returncode == 0:
            log.info(f"Download complete: {model_info['name']}")
        else:
            log.error(f"Download failed: {stderr.decode()}")
    except Exception as e:
        log.error(f"Download error: {e}")


@router.post("/load_custom")
async def load_custom_model(data: LoadCustomModelRequest, request: Request):
    """Load a custom model from an absolute path (no copy — works for LM Studio paths)."""
    llm_svc: LLMService = request.app.state.llm_service

    model_file = Path(data.path)
    if not model_file.exists():
        raise HTTPException(404, f"Custom model file {data.path} not found.")

    # Auto-detect mmproj if not provided
    mmproj = data.mmproj_path
    if not mmproj and settings.mmproj_auto_detect:
        mmproj_candidates = list(model_file.parent.glob(f"*{settings.mmproj_suffix}*.gguf"))
        if mmproj_candidates:
            mmproj = str(mmproj_candidates[0])
            log.info(f"Auto-detected mmproj: {mmproj_candidates[0].name}")

    await llm_svc.load_model(str(model_file), mmproj_path=mmproj)
    return {
        "status": "loaded",
        "model_id": model_file.stem,
        "path": str(model_file),
        "mmproj_path": mmproj,
        "supports_vision": mmproj is not None,
    }


@router.get("/lmstudio")
async def list_lmstudio_models(request: Request):
    """List all models found in the LM Studio model directory."""
    llm_svc: LLMService = request.app.state.llm_service
    models = await asyncio.to_thread(_scan_lmstudio_models)
    # Mark loaded model
    for m in models:
        if hasattr(llm_svc, "current_model_path") and llm_svc.current_model_path:
            m["loaded"] = (
                str(Path(llm_svc.current_model_path).resolve()) ==
                str(Path(m["path"]).resolve())
            )
    return {
        "models": models,
        "total": len(models),
        "lmstudio_dir": str(settings.lmstudio_models_dir),
        "dir_exists": settings.lmstudio_models_dir.exists(),
    }


@router.post("/load/{model_id:path}")
async def load_model(model_id: str, request: Request, data: Optional[LoadModelRequest] = None):
    """Load a model for inference."""
    llm_svc: LLMService = request.app.state.llm_service

    n_ctx = data.n_ctx if data else 4096
    n_gpu_layers = data.n_gpu_layers if data else -1
    n_threads = data.n_threads if data else None
    n_batch = data.n_batch if data else 2048
    quantization = data.quantization if data else 0

    try:
        # Find the model file
        model_file = None

        # Check if it's a direct path (passed as model_id in some cases)
        if Path(model_id).exists() and Path(model_id).is_file():
            model_file = Path(model_id)

        if not model_file:
            search_id = model_id.lower().replace("-", "").replace("_", "")

            for ext in ["*.gguf", "*.litertlm", "*.tflite", "*.bin", "*.task"]:
                for f in settings.models_dir.rglob(ext):
                    fname = f.stem.lower().replace("-", "").replace("_", "")
                    if search_id == fname:  # Exact match first
                        model_file = f
                        break
                    if not model_file and (search_id in fname or fname in search_id):
                        model_file = f
                if model_file:
                    break

        if not model_file:
            # Check if it's an external model
            if llm_svc._client:
                llm_svc._current_model = model_id
                llm_svc._is_ready = True
                return {"status": "loaded", "model_id": model_id, "source": "external"}

            # Check if it's already downloading (look for .lock files)
            is_downloading = any(settings.models_dir.rglob(f"*{model_id}*.lock")) or \
                any(settings.models_dir.rglob("*.gguf.lock"))
            if is_downloading:
                return {
                    "status": "downloading",
                    "message": "Model is currently being downloaded. Please wait."
                }

            raise HTTPException(404, f"Model file for {model_id} not found. Download it first.")

        # Auto-detect mmproj from the same folder if not provided
        mmproj_path = data.mmproj_path if data else None
        if not mmproj_path and model_file and settings.mmproj_auto_detect:
            mmproj_candidates = list(model_file.parent.glob(f"*{settings.mmproj_suffix}*.gguf"))
            if mmproj_candidates:
                mmproj_path = str(mmproj_candidates[0])
                log.info(f"Auto-detected mmproj: {mmproj_candidates[0].name}")

        await llm_svc.load_model(
            str(model_file),
            n_ctx=n_ctx,
            n_gpu_layers=n_gpu_layers,
            n_threads=n_threads,
            n_batch=n_batch,
            quantization=quantization,
            mmproj_path=mmproj_path,
        )
        if not llm_svc.is_ready:
            raise HTTPException(500, "Model failed to load. Check backend logs for details.")

        return {
            "status": "loaded",
            "model_id": model_id,
            "path": str(model_file),
            "mmproj_path": mmproj_path,
            "supports_vision": mmproj_path is not None,
        }
    except HTTPException:
        raise
    except Exception as e:
        log.error("Failed to load model", error=str(e), model_id=model_id)
        raise HTTPException(500, str(e))


@router.post("/unload/{model_id:path}")
async def unload_model(model_id: str, request: Request):
    """Unload the current model from memory."""
    llm_svc: LLMService = request.app.state.llm_service
    await llm_svc.unload_model()
    return {"status": "unloaded"}


@router.get("/server/status")
async def server_status(request: Request):
    """Get inference server status."""
    llm_svc: LLMService = request.app.state.llm_service
    return {
        "running": llm_svc.server_running,
        "ready": llm_svc.is_ready,
        "current_model": llm_svc.current_model,
        "host": settings.llm_server_host,
        "port": settings.llm_server_port,
        "url": settings.llm_server_url,
    }


@router.post("/server/start")
async def start_server(data: StartServerRequest, request: Request):
    """Start the local inference server."""
    llm_svc: LLMService = request.app.state.llm_service

    port = data.port or settings.llm_server_port
    model_path = data.model_path or llm_svc.current_model_path

    if not model_path:
        raise HTTPException(400, "No model selected to start server")

    await llm_svc.start_server(model_path=model_path, port=port, host=data.host)
    return {"status": "starting", "port": port, "model": Path(model_path).stem}


@router.post("/server/stop")
async def stop_server(request: Request):
    """Stop the local inference server."""
    llm_svc: LLMService = request.app.state.llm_service
    await llm_svc.stop_server()
    return {"status": "stopped"}


@router.post("/server/config")
async def update_server_config(data: ServerConfigRequest, request: Request):
    """Update external server configuration (e.g. LM Studio)."""
    llm_svc: LLMService = request.app.state.llm_service

    if data.url:
        settings.llm_server_url = data.url
    if data.host:
        settings.llm_server_host = data.host
    if data.port:
        settings.llm_server_port = data.port

    success = await llm_svc.initialize()
    if success:
        return {
            "status": "connected",
            "url": settings.llm_server_url,
            "model": llm_svc.current_model
        }
    else:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Could not connect to server at {settings.llm_server_url}. "
                "Make sure LM Studio or Ollama is running."
            )
        )
