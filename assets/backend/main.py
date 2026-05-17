import os
import sys

# Apply Windows-specific patches (Encoding, Stability)
if os.name == 'nt':
    try:
        from patch_windows import apply_patches
        apply_patches()
        
        # Disable telemetry for dependencies (Must be before other imports)
        os.environ["CHROMA_TELEMETRY_DISABLE"] = "1"
        os.environ["ANONYMIZED_TELEMETRY"] = "False"
        os.environ["CHROMA_TELEMETRY_ENABLED"] = "0"

        # Safely wrap system streams
        import io
        if not sys.stdin.closed:
            sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
        if not sys.stdout.closed:
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        if not sys.stderr.closed:
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')
    except Exception:
        pass

import asyncio
import warnings
from contextlib import asynccontextmanager
import structlog
import uvicorn
from fastapi import FastAPI, Request

from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from config.settings import settings
from api.routes import chat, models, graph, gsd, github, agents, system
from api.routes import (
    vault,
    worldmonitor,
    codeflow,
    gsd_engine as gsd_engine_router,
    ingest as ingest_router,
    voice,
    health_edu as health_edu_router,
    skills as skills_router,
    company_os as company_os_router,
    voice_agent as voice_agent_router,
)
from api.middleware.auth import FirebaseAuthMiddleware
from services.database import init_db
from services.llm_service import LLMService
from services.graph_service import GraphService
from services.embedding_service import EmbeddingService
from services.vault_service import VaultService
from services.world_monitor_service import WorldMonitorService
from services.codeflow_service import CodeFlowService
from services.gsd_engine import GSDEngine
from services.voice_service import VoiceService
from services.github_service import GitHubService
from services.ingestion_service import IngestionService
from services.rag_service import RAGService
from services.chat_sync_service import ChatSyncService
from services.skills_service import SkillsService
from services.vector_db_service import VectorDBService
from services.citation_engine import CitationEngine

# Suppress pynvml deprecation warning from torch/cuda
warnings.filterwarnings("ignore", category=FutureWarning, module="torch.cuda")

log = structlog.get_logger(__name__)
limiter = Limiter(key_func=get_remote_address)


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("[START] Cyborg backend starting...", version=settings.app_version)

    # Database
    await init_db()
    log.info("[OK] Database ready")

    # LLM service
    llm_svc = LLMService()
    app.state.llm_service = llm_svc

    # Embedding service
    embedding_svc = EmbeddingService()
    app.state.embedding_service = embedding_svc

    # Vault service (AI-OS markdown file system)
    vault_svc = VaultService()
    await vault_svc.initialize()
    app.state.vault_service = vault_svc
    log.info("[OK] Vault ready")

    # Full sync on startup (delayed to allow faster boot)
    async def delayed_sync():
        await asyncio.sleep(5)
        try:
            await vault_svc.rebuild_all_indices()
        except Exception as e:
            log.warning(f"Startup vault sync failed: {e}")
    asyncio.create_task(delayed_sync())

    # Graph service (requires LLM for AI ingestion and Vault for storage)
    graph_svc = GraphService(embedding_svc, llm_svc, vault_svc)
    asyncio.create_task(graph_svc.initialize())
    app.state.graph_service = graph_svc
    log.info("[WAIT] Knowledge graph initializing in background...")

    # Initialize independent services in parallel
    log.info("[START] Parallelizing service boot...")
    
    # Vector DB service (ChromaDB for fast ANN search)
    vector_db_svc = VectorDBService()
    app.state.vector_db_service = vector_db_svc

    # RAG service (Active Retrieval-Augmented Generation + Vector DB)
    rag_svc = RAGService(graph_svc, embedding_svc, vault_svc, llm_svc, vector_db_svc)
    app.state.rag_service = rag_svc

    # Chat Sync service (auto-ingest chat to KG)
    chat_sync_svc = ChatSyncService(graph_svc, llm_svc, vault_svc)
    app.state.chat_sync_service = chat_sync_svc

    # Skills service (dynamic skill creation & execution)
    skills_svc = SkillsService(llm_svc)
    app.state.skills_service = skills_svc

    # GitHub service (Sync & Integration)
    github_svc = GitHubService()
    app.state.github_service = github_svc

    # World monitor service
    world_svc = WorldMonitorService()
    app.state.world_monitor_service = world_svc

    # Voice service
    voice_svc = VoiceService()
    app.state.voice_service = voice_svc

    # Ingestion service
    ingestion_service = IngestionService(vault_svc, voice_svc, graph_svc, llm_svc)
    app.state.ingestion_service = ingestion_service

    # Execute all initializations concurrently in background to allow instant server boot
    async def _initialize_all():
        try:
            log.info("[BOOT] Starting background service initialization...")
            await asyncio.gather(
                llm_svc.initialize(),
                embedding_svc.initialize(),
                vector_db_svc.initialize(),
                rag_svc.initialize(),
                chat_sync_svc.start(),
                skills_svc.initialize(),
                github_svc.initialize(vault_svc),
                ingestion_service.initialize(),
                voice_svc.initialize(),
            )
            
            # Citation Engine (smart citation injection for knowledge queries)
            app.state.citation_engine = CitationEngine(llm_svc)
            
            # CodeFlow service
            app.state.codeflow_service = CodeFlowService()
            
            # GSD execution engine
            app.state.gsd_engine = GSDEngine()
            
            # Company OS automation engine
            from services.company_os import CompanyOSEngine
            app.state.company_os_engine = CompanyOSEngine(llm_service=llm_svc)
            app.state.company_os_engine.start()
            
            log.info("[OK] Background initialization complete")
        except Exception as e:
            log.error(f"[CRITICAL] Background initialization failed: {e}")

    asyncio.create_task(_initialize_all())

    # Background: sync KG nodes to VectorDB once graph is initialized
    async def _sync_kg_to_vdb():
        await asyncio.sleep(5)  # Reduced wait time
        try:
            await rag_svc.sync_all_nodes_to_vector_db()
        except Exception as e:
            log.warning(f"KG→VectorDB background sync failed: {e}")
    asyncio.create_task(_sync_kg_to_vdb())

    # Inject app.state into cross-window tools
    from agents.tools.window_tools import set_app_state as set_window_state
    from agents.tools.rag_tools import set_app_state as set_rag_state
    from agents.tools.visual_tools import set_services as set_visual_services
    set_window_state(app.state)
    set_rag_state(app.state)
    set_visual_services(llm_svc, app.state)

    log.info("[OK] All services ready", host=settings.host, port=settings.port)
    yield

    # Cleanup — sync chat before shutdown
    log.info("[STOP] Shutting down...")

    # Sync all pending chats to KG before shutdown
    if hasattr(app.state, "chat_sync_service"):
        log.info("[SYNC] Syncing pending chats to Knowledge Graph...")
        await app.state.chat_sync_service.stop()
        log.info("[OK] Chat sync complete")
        
    if hasattr(app.state, "company_os_engine"):
        await app.state.company_os_engine.stop()

    await world_svc.close()
    await llm_svc.cleanup()
    if hasattr(app.state, "voice_service"):
        await app.state.voice_service.cleanup()
    if hasattr(app.state, "github_service"):
        await app.state.github_service.cleanup()
    if hasattr(app.state, "ingestion_service"):
        await app.state.ingestion_service.cleanup()

    log.info("[SHUTDOWN] Cyborg backend stopped")


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="Cyborg - Local-First AGI Platform Backend",
        docs_url="/api/docs",
        redoc_url="/api/redoc",
        lifespan=lifespan,
    )

    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(FirebaseAuthMiddleware)

    # -- Routes ----------------------------------------------------------------
    app.include_router(chat.router,               prefix="/api/v1/chat",        tags=["Chat"])
    app.include_router(models.router,             prefix="/api/v1/models",      tags=["Models"])
    app.include_router(graph.router,              prefix="/api/v1/graph",       tags=["Graph"])
    app.include_router(gsd.router,                prefix="/api/v1/gsd",         tags=["GSD"])
    app.include_router(gsd_engine_router.router,  prefix="/api/v1/gsd-engine",  tags=["GSD Engine"])
    app.include_router(github.router,             prefix="/api/v1/github",      tags=["GitHub"])
    app.include_router(agents.router,             prefix="/api/v1/agents",      tags=["Agents"])
    app.include_router(system.router,             prefix="/api/v1/system",      tags=["System"])
    app.include_router(vault.router,              prefix="/api/v1/vault",       tags=["Vault"])
    app.include_router(
        worldmonitor.router,
        prefix="/api/v1/worldmonitor",
        tags=["World Monitor"]
    )
    app.include_router(codeflow.router,           prefix="/api/v1/codeflow",    tags=["CodeFlow"])
    app.include_router(ingest_router.router,       prefix="/api/v1/ingest",       tags=["Ingest"])
    app.include_router(voice.router,               prefix="/api/v1/voice",        tags=["Voice"])
    app.include_router(health_edu_router.router,   prefix="/api/v1",              tags=["Health & Education"])
    app.include_router(skills_router.router,       prefix="/api/v1/skills",       tags=["Skills"])
    app.include_router(company_os_router.router,    prefix="/api/v1",              tags=["Company OS"])
    app.include_router(voice_agent_router.router,   prefix="/api/voice-agent",     tags=["Voice Agent"])

    @app.get("/api/v1/health")
    async def health():
        llm_svc = app.state.llm_service
        voice_svc = app.state.voice_service
        rag_svc = app.state.rag_service
        chat_sync = app.state.chat_sync_service

        status_msg = "online"
        if not llm_svc.is_ready or not voice_svc.is_ready:
            status_msg = "loading"

        return {
            "status": status_msg,
            "version": settings.app_version,
            "llm_ready": llm_svc.is_ready,
            "cuda_active": llm_svc.cuda_active,
            "supports_vision": llm_svc.supports_vision,
            "mmproj_loaded": llm_svc.mmproj_path is not None,
            "voice_ready": voice_svc.is_ready,
            "rag_ready": rag_svc.is_ready,
            "chat_sync": chat_sync.get_sync_status(),
            "skills_count": len(app.state.skills_service.get_all_skills()),
            "vector_db_ready": getattr(app.state, "vector_db_service", None) and app.state.vector_db_service.is_ready,
            "offline_mode": settings.offline_mode,
            "lmstudio_dir_exists": settings.lmstudio_models_dir.exists(),
            "details": {
                "llm": "Ready" if llm_svc.is_ready else "Initializing models...",
                "voice": "Ready" if voice_svc.is_ready else "Loading Whisper/Kokoro...",
                "rag": "Ready" if rag_svc.is_ready else "Initializing RAG...",
                "chat_sync": "Running" if chat_sync._running else "Stopped",
                "vector_db": "Ready" if getattr(app.state, "vector_db_service", None) and app.state.vector_db_service.is_ready else "Unavailable",
            }
        }

    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        log.error("Unhandled exception", error=str(exc), path=request.url.path)
        return JSONResponse(
            status_code=500,
            content={"error": "Internal server error", "detail": str(exc)},
        )

    # Serve static frontend (for Hugging Face Spaces / Web deployment)
    static_dir = os.path.join(os.path.dirname(__file__), "static")
    if os.path.exists(static_dir):
        from fastapi.staticfiles import StaticFiles
        app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
        log.info(f"[OK] Serving static web frontend from {static_dir}")

    return app


app = create_app()

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        workers=1,
        log_level="info",
        loop="asyncio",
    )
