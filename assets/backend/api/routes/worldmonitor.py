"""
World Monitor API Routes
"""
import asyncio
import json
import structlog
from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect

from services.world_monitor_service import WorldMonitorService
from services.llm_service import LLMService

log = structlog.get_logger(__name__)
router = APIRouter()


@router.get("/metrics")
async def get_metrics(request: Request):
    svc: WorldMonitorService = request.app.state.world_monitor_service
    return await svc.get_system_metrics()


@router.get("/news")
async def get_news(category: str = "all", refresh: bool = False,
                   request: Request = None):
    svc: WorldMonitorService = request.app.state.world_monitor_service
    news = await svc.get_news(category=category, force_refresh=refresh)
    return {"news": news, "total": len(news), "category": category}


@router.post("/briefing")
async def get_briefing(request: Request):
    """Generate LLM briefing of current world state."""
    body = await request.json()
    category = body.get("category", "all")
    svc: WorldMonitorService = request.app.state.world_monitor_service
    llm: LLMService = request.app.state.llm_service

    if not llm.is_ready:
        # Return a simple text briefing without LLM
        news = await svc.get_news(category=category)
        headlines = "\n".join(f"• {n['title']}" for n in news[:10])
        return {"briefing": f"Current headlines:\n{headlines}"}

    briefing = await svc.generate_briefing(llm, category=category)
    return {"briefing": briefing}


@router.websocket("/stream")
async def metrics_stream(websocket: WebSocket):
    """Stream system metrics every 2 seconds."""
    await websocket.accept()
    svc: WorldMonitorService = websocket.app.state.world_monitor_service
    try:
        while True:
            metrics = await svc.get_system_metrics()
            await websocket.send_text(json.dumps(metrics))
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        log.debug(f"Metrics stream error: {e}")
