"""
Chat API — REST + WebSocket streaming
Powered by LangGraph agent orchestration.
"""
import json
import asyncio
import structlog
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request, HTTPException
from pydantic import BaseModel
from typing import Optional
from slowapi import Limiter
from slowapi.util import get_remote_address

from services.llm_service import LLMService
from agents.graphs.chat_graph import build_chat_graph
from services.database import ChatSession, get_db
from config.settings import settings

log = structlog.get_logger(__name__)
router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


class ChatRequest(BaseModel):
    session_id: Optional[str] = None
    messages: list[dict]
    model: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 2048
    stream: bool = True


class SessionCreate(BaseModel):
    title: str = "New Chat"


@router.get("/sessions")
async def list_sessions(request: Request):
    """List all chat sessions for current user."""
    user_id = getattr(request.state, "user_id", "local")
    async with get_db() as db:
        sessions = await ChatSession.get_by_user(db, user_id)
    return {"sessions": [s.to_dict() for s in sessions]}


@router.post("/sessions")
async def create_session(data: SessionCreate, request: Request):
    """Create a new chat session."""
    user_id = getattr(request.state, "user_id", "local")
    async with get_db() as db:
        session = await ChatSession.create(db, user_id=user_id, title=data.title)
    return session.to_dict()


@router.post("/")
@limiter.limit("30/minute")
async def chat(data: ChatRequest, request: Request):
    """Non-streaming chat completion."""
    llm_svc: LLMService = request.app.state.llm_service

    if not llm_svc.is_ready:
        raise HTTPException(503, "LLM service not ready yet")

    graph = build_chat_graph(llm_svc)
    result = await graph.ainvoke({
        "messages": data.messages,
        "model": data.model or llm_svc.current_model,
        "session_id": data.session_id,
    })

    return {
        "message": result["output"],
        "model": result.get("model"),
        "usage": result.get("usage", {}),
    }


@router.websocket("/stream")
async def chat_stream(websocket: WebSocket):
    """
    WebSocket endpoint for streaming chat responses.
    Accepts: {"type": "chat", "messages": [...], "model": "...", "session_id": "..."}
    Sends: {"type": "token", "token": "..."} | {"type": "done"} | {"type": "error"}
    """
    await websocket.accept()
    log.info("WebSocket chat connection opened")

    try:
        while True:
            raw = await asyncio.wait_for(websocket.receive_text(), timeout=120)
            data = json.loads(raw)

            if data.get("type") != "chat":
                continue

            llm_svc: LLMService = websocket.app.state.llm_service

            if not llm_svc.is_ready:
                await websocket.send_text(json.dumps({
                    "type": "error",
                    "message": "LLM not loaded. Please load a model in the Models tab."
                }))
                continue

            messages = data.get("messages", [])
            model_name = data.get("model")
            use_voice = data.get("voice", False)
            voice_name = data.get("voice_name", settings.default_voice)

            if use_voice and hasattr(websocket.app.state, "voice_service"):
                websocket.app.state.voice_service.stop()

            try:
                # 1. Truncate history to avoid context overflow (keep last 20 messages)
                if len(messages) > 20:
                    if messages[0].get("role") == "system":
                        messages = [messages[0]] + messages[-19:]
                    else:
                        messages = messages[-20:]

                if use_voice:
                    # 2. Add voice-optimized system prompt ONLY if not already present
                    has_system = any(m.get("role") == "system" for m in messages)
                    if not has_system:
                        voice_prompt = {
                            "role": "system",
                            "content": (
                                "You are Jarvis, a helpful voice assistant. "
                                "Respond in clear natural spoken sentences. "
                                "No markdown, no bullet points, no lists."
                            )
                        }
                        messages.insert(0, voice_prompt)

                log.info("Starting chat stream", messages_count=len(messages), model=model_name)
                # Stream tokens
                async for token in llm_svc.stream_chat(messages, model=model_name):
                    log.debug("Token generated", token_len=len(token))

                    if use_voice and hasattr(websocket.app.state, "voice_service"):
                        websocket.app.state.voice_service.process_token(token, voice_name)

                    await websocket.send_text(json.dumps({
                        "type": "token",
                        "token": token,
                    }))

                if use_voice and hasattr(websocket.app.state, "voice_service"):
                    websocket.app.state.voice_service.finalize_stream(voice_name)

                log.info("Chat stream complete")
                await websocket.send_text(json.dumps({"type": "done"}))

            except Exception as e:
                log.error("Chat streaming error", error=str(e))
                await websocket.send_text(json.dumps({
                    "type": "error",
                    "message": str(e),
                }))

    except WebSocketDisconnect:
        log.info("WebSocket chat disconnected")
    except asyncio.TimeoutError:
        await websocket.close(code=1001, reason="Idle timeout")
    except Exception as e:
        log.error("WebSocket error", error=str(e))
        try:
            await websocket.close(code=1011)
        except Exception:
            pass
