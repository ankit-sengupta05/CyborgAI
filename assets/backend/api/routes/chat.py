"""
Chat API — REST + WebSocket streaming with Active RAG.

Powered by LangGraph agent orchestration with:
- RAG-augmented context injection
- Chat history → Knowledge Graph sync
- Cross-window intelligence routing
- Voice response support
"""
import json
import asyncio
import structlog
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional
from slowapi import Limiter
from slowapi.util import get_remote_address

from services.llm_service import LLMService
from agents.graphs.chat_graph import build_chat_graph
from services.database import ChatSession, get_db
from services.vault_service import VaultService
from config.settings import settings

log = structlog.get_logger(__name__)
router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


async def _save_chat_to_vault(vault: VaultService, session_id: str, messages: list):
    """Save chat messages to vault as a markdown note."""
    try:
        title = f"Chat_{session_id}"[:30]
        content = f"# Chat History: {session_id}\n\n"
        for m in messages:
            role = m.get("role", "unknown").capitalize()
            content += f"### {role}\n{m.get('content', '')}\n\n"

        # Check if note exists
        existing = await vault.get_note(title.lower())
        if existing:
            await vault.update_note(existing["id"], content=content)
        else:
            await vault.create_note(
                title=title, content=content, folder="Archive", tags=["chat-history"], note_type="chat_log"
            )
    except Exception as e:
        log.error("Failed to save chat to vault", error=str(e))


async def _sync_message_to_kg(app_state, session_id: str, message: dict):
    """Track a message for Knowledge Graph sync."""
    if hasattr(app_state, "chat_sync_service"):
        try:
            await app_state.chat_sync_service.track_message(session_id, message)
        except Exception as e:
            log.debug(f"Chat sync track failed: {e}")


class ChatRequest(BaseModel):
    session_id: Optional[str] = None
    messages: list[dict]
    model: Optional[str] = None
    temperature: float = 0.7
    max_tokens: int = 2048
    stream: bool = True
    use_rag: bool = True  # Enable RAG by default


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
    """Non-streaming chat completion with RAG augmentation."""
    llm_svc: LLMService = request.app.state.llm_service

    if not llm_svc.is_ready:
        raise HTTPException(503, "LLM service not ready yet")

    # Build chat graph with RAG service
    rag_svc = getattr(request.app.state, "rag_service", None) if data.use_rag else None
    graph = build_chat_graph(llm_svc, rag_svc)

    result = await graph.ainvoke({
        "messages": data.messages,
        "model": data.model or llm_svc.current_model,
        "session_id": data.session_id,
    })

    # Track messages for KG sync
    if data.session_id:
        for msg in data.messages:
            await _sync_message_to_kg(request.app.state, data.session_id, msg)
        await _sync_message_to_kg(
            request.app.state, data.session_id,
            {"role": "assistant", "content": result["output"]}
        )

        # Also save to vault
        if hasattr(request.app.state, "vault_service"):
            all_msgs = data.messages + [{"role": "assistant", "content": result["output"]}]
            asyncio.create_task(_save_chat_to_vault(request.app.state.vault_service, data.session_id, all_msgs))

    return {
        "message": result["output"],
        "model": result.get("model"),
        "usage": result.get("usage", {}),
    }


@router.get("/sync/status")
async def get_sync_status(request: Request):
    """Get chat-to-KG sync status."""
    if hasattr(request.app.state, "chat_sync_service"):
        return request.app.state.chat_sync_service.get_sync_status()
    return {"running": False}


@router.post("/sync/now")
async def trigger_sync(request: Request):
    """Manually trigger chat-to-KG sync."""
    if hasattr(request.app.state, "chat_sync_service"):
        await request.app.state.chat_sync_service.sync_all_pending()
        return {"status": "synced"}
    raise HTTPException(503, "Chat sync not available")


@router.post("/completions")
async def chat_completions(request: Request):
    """OpenAI-compatible chat completions endpoint for internal agent tools."""
    llm_svc: LLMService = request.app.state.llm_service
    if not llm_svc._llm:
        raise HTTPException(503, "Local LLM is not loaded")
    
    body = await request.json()
    messages = body.get("messages", [])
    tools = body.get("tools", None)
    log.info(f"Completions request: messages={len(messages)}, tools={len(tools) if tools else 0}, stream={body.get('stream', False)}")
    
    try:
        loop = asyncio.get_event_loop()
        is_stream = body.get("stream", False)
        
        if is_stream:
            queue = asyncio.Queue()
            
            def _run_stream():
                try:
                    with llm_svc._inference_lock:
                        stream = llm_svc._llm.create_chat_completion(
                            messages=messages,
                            tools=tools,
                            temperature=body.get("temperature", 0.7),
                            max_tokens=body.get("max_tokens", 1024),
                            stream=True,
                        )
                        for chunk in stream:
                            # log.debug(f"Chunk: {chunk}")
                            loop.call_soon_threadsafe(queue.put_nowait, chunk)
                        loop.call_soon_threadsafe(queue.put_nowait, None)
                except Exception as e:
                    log.error(f"Stream generation error: {e}", exc_info=True)
                    loop.call_soon_threadsafe(queue.put_nowait, e)
                    
            loop.run_in_executor(None, _run_stream)
            
            async def event_generator():
                while True:
                    item = await queue.get()
                    if item is None:
                        yield "data: [DONE]\n\n"
                        break
                    if isinstance(item, Exception):
                        log.error(f"Stream error: {item}")
                        yield f"data: {json.dumps({'error': str(item)})}\n\n"
                        break
                    # log.debug(f"Yielding: {item}")
                    yield f"data: {json.dumps(item)}\n\n"
                    
            return StreamingResponse(event_generator(), media_type="text/event-stream")
            
        else:
            def _run_sync():
                with llm_svc._inference_lock:
                    return llm_svc._llm.create_chat_completion(
                        messages=messages,
                        tools=tools,
                        temperature=body.get("temperature", 0.7),
                        max_tokens=body.get("max_tokens", 1024),
                        stream=False,
                    )
            
            result = await loop.run_in_executor(None, _run_sync)
            log.info(f"Completions result: {result.get('choices', [{}])[0].get('message', {})}")
            return result
            
    except Exception as e:
        log.error(f"OpenAI compatible completion failed: {e}")
        raise HTTPException(500, str(e))


@router.websocket("/stream")
async def chat_stream(websocket: WebSocket):
    """
    WebSocket endpoint for streaming chat responses with RAG augmentation.

    Accepts: {"type": "chat", "messages": [...], "model": "...", "session_id": "...", "use_rag": true}
    Sends: {"type": "token", "token": "..."} | {"type": "done", "sync_status": {...}} | {"type": "error"}
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
            session_id = data.get("session_id")
            use_voice = data.get("voice", False)
            voice_name = data.get("voice_name", settings.default_voice)
            use_rag = data.get("use_rag", True)

            if use_voice and hasattr(websocket.app.state, "voice_service"):
                websocket.app.state.voice_service.stop()

            try:
                # 1. Truncate history to avoid context overflow (keep last 10 messages)
                if len(messages) > 10:
                    if messages[0].get("role") == "system":
                        messages = [messages[0]] + messages[-9:]
                    else:
                        messages = messages[-10:]

                # 2. RAG augmentation — inject knowledge context
                if use_rag and hasattr(websocket.app.state, "rag_service"):
                    rag_svc = websocket.app.state.rag_service
                    if rag_svc.is_ready:
                        try:
                            messages = await rag_svc.augment_messages(messages)
                        except Exception as e:
                            log.debug(f"RAG augmentation skipped: {e}")

                if use_voice:
                    # 3. Add voice-optimized system prompt ONLY if not already present
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

                log.info("Starting chat stream", messages_count=len(messages), model=model_name, rag=use_rag)

                # Stream tokens via LangGraph Agent
                full_response = []
                rag_svc = getattr(websocket.app.state, "rag_service", None) if use_rag else None
                graph = build_chat_graph(llm_svc, rag_svc)
                
                try:
                    # v2 is recommended for langchain-core >= 0.2.0
                    async for event in graph.astream_events(
                        {"messages": messages, "model": model_name, "session_id": session_id},
                        version="v2"
                    ):
                        kind = event["event"]
                        
                        if kind == "on_chat_model_stream":
                            chunk = event["data"]["chunk"]
                            if hasattr(chunk, "content") and chunk.content and isinstance(chunk.content, str):
                                token = chunk.content
                                full_response.append(token)

                                if use_voice and hasattr(websocket.app.state, "voice_service"):
                                    websocket.app.state.voice_service.process_token(token, voice_name)

                                await websocket.send_text(json.dumps({
                                    "type": "token",
                                    "token": token,
                                }))
                                # log.debug(f"Streamed token: {token}")
                                await asyncio.sleep(0.01)  # Pacing for UI stability
                        
                        elif kind == "on_tool_start":
                            tool_name = event["name"]
                            tool_msg = f"\n\n*Using tool: {tool_name}...*\n\n"
                            full_response.append(tool_msg)
                            await websocket.send_text(json.dumps({
                                "type": "token",
                                "token": tool_msg,
                            }))

                except Exception as graph_err:
                    log.error(f"Graph streaming error: {graph_err}. Falling back to direct LLM.")
                    async for token in llm_svc.stream_chat(messages, model=model_name):
                        full_response.append(token)

                        if use_voice and hasattr(websocket.app.state, "voice_service"):
                            websocket.app.state.voice_service.process_token(token, voice_name)

                        await websocket.send_text(json.dumps({
                            "type": "token",
                            "token": token,
                        }))

                if use_voice and hasattr(websocket.app.state, "voice_service"):
                    websocket.app.state.voice_service.finalize_stream(voice_name)

                # 4. Track messages for KG sync
                if session_id:
                    # Track user message
                    user_msg = next((m for m in reversed(data.get("messages", [])) if m.get("role") == "user"), None)
                    if user_msg:
                        await _sync_message_to_kg(websocket.app.state, session_id, user_msg)

                    # Track assistant response
                    assistant_text = "".join(full_response)
                    await _sync_message_to_kg(
                        websocket.app.state, session_id,
                        {"role": "assistant", "content": assistant_text}
                    )

                # Get sync status for frontend indicator
                sync_status = {}
                if hasattr(websocket.app.state, "chat_sync_service"):
                    sync_status = websocket.app.state.chat_sync_service.get_sync_status()

                log.info("Chat stream complete")
                await websocket.send_text(json.dumps({
                    "type": "done",
                    "sync_status": sync_status,
                }))

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
