"""
Chat API — REST + WebSocket streaming with Active RAG + Citations + Multimodal.

Powered by LangGraph agent orchestration with:
- RAG-augmented context injection (Vector DB + Knowledge Graph)
- Smart citation engine (knowledge queries only)
- Multimodal endpoint (images + documents + audio)
- Chat history → Knowledge Graph sync
- Cross-window intelligence routing
- Voice response support
"""
import json
import asyncio
import tempfile
import base64
import os
import structlog
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request, HTTPException, UploadFile, File, Form
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

# Temporary upload directory for multimodal files
_UPLOAD_DIR = settings.data_dir / "uploads"
_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Supported file types for multimodal inference
_IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}
_AUDIO_EXTS = {".wav", ".mp3", ".ogg", ".m4a", ".flac"}
_DOC_EXTS = {".pdf", ".docx", ".txt", ".md", ".pptx", ".csv"}


async def _save_chat_to_vault(vault: VaultService, session_id: str, messages: list):
    """Save chat messages to vault as a markdown note."""
    try:
        title = f"Chat_{session_id}"[:30]
        content = f"# Chat History: {session_id}\n\n"
        for m in messages:
            role = m.get("role", "unknown").capitalize()
            msg_content = m.get("content", "")
            if isinstance(msg_content, list):
                # Multimodal content — extract text parts
                text_parts = [p.get("text", "") for p in msg_content if isinstance(p, dict) and p.get("type") == "text"]
                msg_content = " ".join(text_parts)
            content += f"### {role}\n{msg_content}\n\n"

        existing = await vault.get_note(title.lower())
        if existing:
            await vault.update_note(existing["id"], content=content)
        else:
            await vault.create_note(
                title=title, content=content, folder="Archive",
                tags=["chat-history"], note_type="chat_log"
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


async def _extract_text_from_file(file_path: str) -> str:
    """Extract text from uploaded document files."""
    from pathlib import Path
    path = Path(file_path)
    try:
        from services.utils.text_extractor import extract_text as _ext
        return await _ext(path)
    except Exception as e:
        log.warning(f"Text extraction failed for {path.name}: {e}")
        return ""


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


# ── Session management ────────────────────────────────────────────────────────

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


# ── Standard chat ─────────────────────────────────────────────────────────────

@router.post("/")
@limiter.limit("30/minute")
async def chat(data: ChatRequest, request: Request):
    """Non-streaming chat completion with RAG augmentation + citations."""
    llm_svc: LLMService = request.app.state.llm_service

    if not llm_svc.is_ready:
        raise HTTPException(503, "LLM service not ready yet")

    rag_svc = getattr(request.app.state, "rag_service", None) if data.use_rag else None
    graph = build_chat_graph(llm_svc, rag_svc)

    result = await graph.ainvoke({
        "messages": data.messages,
        "model": data.model or llm_svc.current_model,
        "session_id": data.session_id,
    })

    # Citation engine
    response_text = result["output"]
    citations = []
    citation_svc = getattr(request.app.state, "citation_engine", None)
    if citation_svc and rag_svc and data.use_rag:
        user_query = next(
            (m.get("content", "") for m in reversed(data.messages) if m.get("role") == "user"),
            ""
        )
        retrieval = await rag_svc.retrieve(user_query, top_k=5)
        response_text, citations = citation_svc.attach_citations(
            response_text, retrieval.get("sources", []), user_query
        )

    if data.session_id:
        for msg in data.messages:
            await _sync_message_to_kg(request.app.state, data.session_id, msg)
        await _sync_message_to_kg(
            request.app.state, data.session_id,
            {"role": "assistant", "content": result["output"]}
        )
        if hasattr(request.app.state, "vault_service"):
            all_msgs = data.messages + [{"role": "assistant", "content": result["output"]}]
            asyncio.create_task(_save_chat_to_vault(request.app.state.vault_service, data.session_id, all_msgs))

    return {
        "message": response_text,
        "model": result.get("model"),
        "usage": result.get("usage", {}),
        "citations": citations,
        "has_citations": len(citations) > 0,
    }


# ── Multimodal chat ───────────────────────────────────────────────────────────

@router.post("/multimodal")
@limiter.limit("20/minute")
async def chat_multimodal(
    request: Request,
    prompt: str = Form(...),
    session_id: Optional[str] = Form(None),
    temperature: float = Form(0.7),
    max_tokens: int = Form(2048),
    use_rag: bool = Form(True),
    files: list[UploadFile] = File(default=[]),
):
    """
    Multimodal chat — accepts text + images + audio + documents.

    - Images: passed to the vision-capable model (requires mmproj)
    - Audio: transcribed and appended to prompt
    - Documents: text extracted and injected as context
    """
    llm_svc: LLMService = request.app.state.llm_service

    if not llm_svc.is_ready:
        raise HTTPException(503, "LLM service not ready yet")

    image_paths: list[str] = []
    audio_paths: list[str] = []
    doc_texts: list[str] = []
    saved_files: list[str] = []

    try:
        # Save and classify uploaded files
        for upload in files:
            ext = os.path.splitext(upload.filename or "")[1].lower()
            suffix = ext or ".bin"
            tmp = tempfile.NamedTemporaryFile(
                delete=False, suffix=suffix, dir=str(_UPLOAD_DIR)
            )
            tmp.write(await upload.read())
            tmp.close()
            saved_files.append(tmp.name)

            if ext in _IMAGE_EXTS:
                image_paths.append(tmp.name)
            elif ext in _AUDIO_EXTS:
                audio_paths.append(tmp.name)
            elif ext in _DOC_EXTS:
                doc_text = await _extract_text_from_file(tmp.name)
                if doc_text:
                    doc_texts.append(doc_text[:3000])

        # Build augmented prompt
        full_prompt = prompt
        if doc_texts:
            doc_context = "\n\n".join(f"[Document]\n{t}" for t in doc_texts)
            full_prompt = f"{doc_context}\n\n---\n{prompt}"

        # Transcribe audio if present
        if audio_paths and hasattr(request.app.state, "voice_service"):
            voice_svc = request.app.state.voice_service
            for ap in audio_paths:
                try:
                    transcription = await asyncio.to_thread(voice_svc.transcribe_file, ap)
                    if transcription:
                        full_prompt += f"\n\n[Audio transcription]: {transcription}"
                except Exception as e:
                    log.warning(f"Audio transcription failed: {e}")

        # RAG augmentation on full prompt
        rag_context = ""
        rag_sources = []
        rag_svc = getattr(request.app.state, "rag_service", None)
        if use_rag and rag_svc and rag_svc.is_ready:
            try:
                retrieval = await rag_svc.retrieve(prompt, top_k=5, max_tokens=1000)
                rag_context = retrieval.get("context", "")
                rag_sources = retrieval.get("sources", [])
            except Exception as e:
                log.debug(f"RAG augmentation skipped: {e}")

        if rag_context:
            full_prompt = f"## Context from Knowledge Base\n{rag_context}\n\n---\n{full_prompt}"

        # Stream response
        full_response = []
        async for tok in llm_svc.stream_chat_multimodal(
            text_prompt=full_prompt,
            image_paths=image_paths if llm_svc.supports_vision else [],
            temperature=temperature,
            max_tokens=max_tokens,
        ):
            full_response.append(tok)

        response_text = "".join(full_response)

        # Citations
        citations = []
        citation_svc = getattr(request.app.state, "citation_engine", None)
        if citation_svc:
            response_text, citations = citation_svc.attach_citations(
                response_text, rag_sources, prompt
            )

        return {
            "message": response_text,
            "model": llm_svc.current_model,
            "supports_vision": llm_svc.supports_vision,
            "files_processed": {
                "images": len(image_paths),
                "audio": len(audio_paths),
                "documents": len(doc_texts),
            },
            "citations": citations,
            "has_citations": len(citations) > 0,
        }
    finally:
        # Clean up temp files
        for fp in saved_files:
            try:
                os.unlink(fp)
            except Exception:
                pass


# ── Sync ──────────────────────────────────────────────────────────────────────

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


# ── OpenAI-compatible completions ────────────────────────────────────────────

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

    # ── Context Budget Management ─────────────────────────────────────────────
    # Filter poisoned frontend error responses from history
    messages = [m for m in messages if not (m.get("role") == "assistant" and isinstance(m.get("content"), str) and "No LLM loaded" in m["content"])]

    # Hard truncate message history to prevent n_ctx overflow.
    # System messages are always kept; we keep the last 4 chat turns.
    system_msgs = [m for m in messages if m.get("role") == "system"]
    chat_msgs = [m for m in messages if m.get("role") != "system"]
    if len(chat_msgs) > 8:
        chat_msgs = chat_msgs[-8:]  # Keep only the last 8 chat messages
    messages = system_msgs + chat_msgs

    # Truncate each system message to 4000 chars to prevent RAG + system prompt overflow
    for m in messages:
        if m.get("role") == "system" and isinstance(m.get("content"), str):
            if len(m["content"]) > 4000:
                m["content"] = m["content"][:4000] + "...[truncated]"

    # Slim tool definitions: cap descriptions and select relevant tools
    if tools:
        # Determine which tool categories are needed from recent messages
        recent_text = " ".join(
            str(m.get("content", "")) for m in chat_msgs[-3:]
        ).lower()

        # Priority selection based on message intent
        ALWAYS_INCLUDE = {"browser_get_credentials", "browser_navigate",
                          "browser_click", "browser_type_text", "browser_take_screenshot",
                          "browser_get_interactive_elements"}
        WHATSAPP_TOOLS = {"whatsapp_send_message", "desktop_open_app", "desktop_focus_window",
                          "desktop_type_text", "desktop_press_keys", "desktop_screenshot",
                          "desktop_click", "desktop_list_open_windows"}
        RAG_TOOLS = {"rag_search", "get_graph_context", "search_vault_notes"}
        CODE_TOOLS = {"run_python"}

        selected_names = set(ALWAYS_INCLUDE)
        if any(w in recent_text for w in ["whatsapp", "telegram", "discord", "spotify", "desktop", "app", "open"]):
            selected_names |= WHATSAPP_TOOLS
        if any(w in recent_text for w in ["knowledge", "search", "vault", "notes", "graph"]):
            selected_names |= RAG_TOOLS
        if any(w in recent_text for w in ["python", "code", "script", "run", "execute"]):
            selected_names |= CODE_TOOLS

        # Filter and slim down tool definitions
        slimmed_tools = []
        for t in tools:
            fn = t.get("function", {})
            name = fn.get("name", "")
            if name not in selected_names:
                continue
            # Cap description length to 100 chars
            desc = fn.get("description", "")
            if len(desc) > 100:
                fn = dict(fn)
                fn["description"] = desc[:100] + "..."
                t = dict(t)
                t["function"] = fn
            slimmed_tools.append(t)

        tools = slimmed_tools or tools[:8]  # Fallback: first 8 tools
        log.info(f"Slimmed tools from original to {len(tools)} relevant tools")

    try:
        loop = asyncio.get_event_loop()
        is_stream = body.get("stream", False)

        if is_stream:
            queue = asyncio.Queue()
            stop_tokens = ["<|im_end|>", "<|endoftext|>", "<end_of_turn>", "<eos>", "<|eot_id|>", "<|end_of_text|>", "</tool>"]

            def _run_stream():
                try:
                    with llm_svc._inference_lock:
                        stream = llm_svc._llm.create_chat_completion(
                            messages=messages,
                            tools=tools,
                            temperature=body.get("temperature", 0.7),
                            max_tokens=body.get("max_tokens", 1024),
                            stream=True,
                            stop=stop_tokens,
                        )
                        for chunk in stream:
                            loop.call_soon_threadsafe(queue.put_nowait, chunk)
                        loop.call_soon_threadsafe(queue.put_nowait, None)
                except Exception as e:
                    log.error(f"Stream generation error: {e}", exc_info=True)
                    loop.call_soon_threadsafe(queue.put_nowait, e)

            loop.run_in_executor(None, _run_stream)

            async def event_generator():
                """
                Stream tokens, buffering silently when the model writes <tool> XML.
                On stream end, emit a synthetic OpenAI tool_calls chunk so LangChain
                routes it through the ToolNode for actual execution.
                """
                import json as _json, uuid as _uuid
                import re
                text_buffer = ""
                tool_detected = False
                chunk_idx = 0
                model_id = body.get("model", "local-model")

                while True:
                    item = await queue.get()

                    if item is None:
                        # Stream finished
                        if tool_detected and ("<tool>" in text_buffer or "<|tool_call|>" in text_buffer or "<tool_code>" in text_buffer or "<tool_call>" in text_buffer):
                            # Parse XML or Gemma Native and emit as tool_calls
                            try:
                                import re
                                
                                tool_name = "unknown"
                                tool_args = {}
                                
                                # Try extracting content from any <tool...> tag
                                xml_match = re.search(r'<(?:tool|tool_code)[^>]*>(.*?)(?:</(?:tool|tool_code)[^>]*>|\Z)', text_buffer, re.DOTALL)
                                if xml_match:
                                    content = xml_match.group(1).strip()
                                    if content.startswith('{'):
                                        # Try JSON parse
                                        try:
                                            import json as _json
                                            tool_data = _json.loads(content)
                                            tool_name = tool_data.get("name", "unknown")
                                            tool_args = tool_data.get("args", {})
                                        except Exception:
                                            pass
                                    if tool_name == "unknown":
                                        # Maybe it's python code like `list_windows()`
                                        py_match_inner = re.search(r'([a-zA-Z0-9_]+)\((.*?)\)', content)
                                        if py_match_inner:
                                            tool_name = py_match_inner.group(1)
                                            args_str = py_match_inner.group(2)
                                            if args_str:
                                                pairs = re.findall(r'([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^,\)]+))', args_str)
                                                for key, val_double, val_single, val_plain in pairs:
                                                    val = val_double or val_single or val_plain
                                                    val = val.strip() if val else ""
                                                    if val.isdigit(): val = int(val)
                                                    elif val.lower() == "true": val = True
                                                    elif val.lower() == "false": val = False
                                                    tool_args[key] = val
                                else:
                                    import re
                                    
                                    # Format 1: <|tool_call|>call:func_name{args}  (JSON-like)
                                    # Format 2: <tool_call>call:func_name(args)    (Python-like)
                                    tool_name = "unknown"
                                    tool_args = {}
                                    
                                    json_match = re.search(r'<\|?tool_call\|?>call:([a-zA-Z0-9_]+)\s*\{(.*?)\}', text_buffer)
                                    py_match = re.search(r'<\|?tool_call\|?>call:([a-zA-Z0-9_]+)\((.*?)\)', text_buffer)
                                    
                                    if json_match:
                                        tool_name = json_match.group(1)
                                        args_str = json_match.group(2)
                                        if args_str and args_str != "{}":
                                            pairs = re.findall(r'([a-zA-Z0-9_]+)\s*:\s*(?:<\|\*\|>(.*?)<\|\*\|>|"(.*?)"|\'(.*?)\'|([a-zA-Z0-9_.-]+))', args_str)
                                            for key, val_starred, val_double, val_single, val_plain in pairs:
                                                val = val_starred or val_double or val_single or val_plain
                                                val = val.strip() if val else ""
                                                if val.isdigit(): val = int(val)
                                                elif val.lower() == "true": val = True
                                                elif val.lower() == "false": val = False
                                                tool_args[key] = val
                                    elif py_match:
                                        tool_name = py_match.group(1)
                                        args_str = py_match.group(2)
                                        if args_str:
                                            # Simple parsing for kwargs like query='search term', n=5
                                            pairs = re.findall(r'([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^,\)]+))', args_str)
                                            for key, val_double, val_single, val_plain in pairs:
                                                val = val_double or val_single or val_plain
                                                val = val.strip() if val else ""
                                                if val.isdigit(): val = int(val)
                                                elif val.lower() == "true": val = True
                                                elif val.lower() == "false": val = False
                                                tool_args[key] = val
                                    else:
                                        log.error(f"Failed to parse native tool call from buffer: {text_buffer}")
                                        raise ValueError("Could not match Gemma native pattern")

                                call_id = f"call_{_uuid.uuid4().hex[:12]}"
                                tool_chunk = {
                                    "id": f"chatcmpl-{_uuid.uuid4().hex[:8]}",
                                    "object": "chat.completion.chunk",
                                    "model": model_id,
                                    "choices": [{
                                        "index": 0,
                                        "delta": {
                                            "role": "assistant",
                                            "content": None,
                                            "tool_calls": [{
                                                "index": 0,
                                                "id": call_id,
                                                "type": "function",
                                                "function": {
                                                    "name": tool_name,
                                                    "arguments": _json.dumps(tool_args)
                                                }
                                            }]
                                        },
                                        "finish_reason": "tool_calls"
                                    }]
                                }
                                yield f"data: {_json.dumps(tool_chunk)}\n\n"
                                log.info(f"Converted XML/Native to tool_call: {tool_name}({tool_args})")
                            except Exception as parse_err:
                                log.error(f"Tool parse failed: {parse_err}")
                                fallback = {
                                    "id": f"chatcmpl-{chunk_idx}",
                                    "object": "chat.completion.chunk",
                                    "model": model_id,
                                    "choices": [{"index": 0, "delta": {"content": text_buffer}, "finish_reason": "stop"}]
                                }
                                yield f"data: {_json.dumps(fallback)}\n\n"
                        elif text_buffer:
                            flush = {
                                "id": f"chatcmpl-{chunk_idx}",
                                "object": "chat.completion.chunk",
                                "model": model_id,
                                "choices": [{"index": 0, "delta": {"content": text_buffer}, "finish_reason": "stop"}]
                            }
                            yield f"data: {_json.dumps(flush)}\n\n"
                        yield "data: [DONE]\n\n"
                        break

                    if isinstance(item, Exception):
                        log.error(f"Stream error: {item}")
                        yield f"data: {json.dumps({'error': str(item)})}\n\n"
                        break

                    delta = item.get("choices", [{}])[0].get("delta", {})
                    token = delta.get("content", "")
                    if not token:
                        continue

                    text_buffer += token

                    if tool_detected:
                        continue  # Buffer silently — don't leak XML to UI

                    tag_match = re.search(r'(<tool|<\|tool_call\|>|<tool_call|<tool_code)', text_buffer)
                    if tag_match:
                        tool_detected = True
                        tag = tag_match.group(1)
                        text_before = text_buffer.split(tag)[0]
                        if text_before:
                            chunk_idx += 1
                            safe = {
                                "id": f"chatcmpl-{chunk_idx}",
                                "object": "chat.completion.chunk",
                                "model": model_id,
                                "choices": [{"index": 0, "delta": {"content": text_before}, "finish_reason": None}]
                            }
                            yield f"data: {_json.dumps(safe)}\n\n"
                        continue

                    # Check partial match
                    is_partial = False
                    for tag in ["<tool>", "<tool_code>", "<|tool_call|>", "<tool_call>", "</tool>", "</tool_code>"]:
                        for i in range(1, len(tag) + 1):
                            if text_buffer.endswith(tag[:i]):
                                is_partial = True
                                break
                        if is_partial:
                            break
                            
                    if is_partial:
                        continue

                    # Normal token — stream accumulated buffer
                    chunk_idx += 1
                    safe = {
                        "id": f"chatcmpl-{chunk_idx}",
                        "object": "chat.completion.chunk",
                        "model": model_id,
                        "choices": [{"index": 0, "delta": {"content": text_buffer}, "finish_reason": None}]
                    }
                    yield f"data: {_json.dumps(safe)}\n\n"
                    text_buffer = ""

            return StreamingResponse(event_generator(), media_type="text/event-stream")

        else:
            def _run_sync():
                stop_tokens = ["<|im_end|>", "<|endoftext|>", "<end_of_turn>", "<eos>", "<|eot_id|>", "<|end_of_text|>", "</tool>"]
                with llm_svc._inference_lock:
                    return llm_svc._llm.create_chat_completion(
                        messages=messages,
                        tools=tools,
                        temperature=body.get("temperature", 0.7),
                        max_tokens=body.get("max_tokens", 1024),
                        stream=False,
                        stop=stop_tokens,
                    )

            result = await loop.run_in_executor(None, _run_sync)

            # Post-process: convert <tool> XML or Gemma native tags in content to proper tool_calls
            try:
                import uuid as _uuid
                choice = result.get("choices", [{}])[0]
                msg = choice.get("message", {})
                content = msg.get("content", "") or ""
                if not msg.get("tool_calls") and ("<tool>" in content or "<tool_call>" in content or "<|tool_call|>" in content or "<|tool_call>call:" in content):
                    if "<tool>" in content:
                        start = content.find("<tool>") + 6
                        end = content.find("</tool>")
                        if end == -1:
                            end = content.rfind("}") + 1
                        tool_data = json.loads(content[start:end].strip())
                        tool_name = tool_data.get("name", "unknown")
                        tool_args = tool_data.get("args", {})
                    else:
                        import re
                        tool_name = "unknown"
                        tool_args = {}
                        
                        json_match = re.search(r'<\|?tool_call\|?>call:([a-zA-Z0-9_]+)\s*\{(.*?)\}', content)
                        py_match = re.search(r'<\|?tool_call\|?>call:([a-zA-Z0-9_]+)\((.*?)\)', content)
                        
                        if json_match:
                            tool_name = json_match.group(1)
                            args_str = json_match.group(2)
                            if args_str and args_str != "{}":
                                pairs = re.findall(r'([a-zA-Z0-9_]+)\s*:\s*(?:<\|\*\|>(.*?)<\|\*\|>|"(.*?)"|\'(.*?)\'|([a-zA-Z0-9_.-]+))', args_str)
                                for key, val_starred, val_double, val_single, val_plain in pairs:
                                    val = val_starred or val_double or val_single or val_plain
                                    val = val.strip() if val else ""
                                    if val.isdigit(): val = int(val)
                                    elif val.lower() == "true": val = True
                                    elif val.lower() == "false": val = False
                                    tool_args[key] = val
                        elif py_match:
                            tool_name = py_match.group(1)
                            args_str = py_match.group(2)
                            if args_str:
                                pairs = re.findall(r'([a-zA-Z0-9_]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^,\)]+))', args_str)
                                for key, val_double, val_single, val_plain in pairs:
                                    val = val_double or val_single or val_plain
                                    val = val.strip() if val else ""
                                    if val.isdigit(): val = int(val)
                                    elif val.lower() == "true": val = True
                                    elif val.lower() == "false": val = False
                                    tool_args[key] = val
                        else:
                            raise ValueError("Could not match native pattern in sync completions")
                    
                    call_id = f"call_{_uuid.uuid4().hex[:12]}"
                    msg["tool_calls"] = [{
                        "id": call_id,
                        "type": "function",
                        "function": {"name": tool_name, "arguments": json.dumps(tool_args)}
                    }]
                    msg["content"] = None
                    choice["finish_reason"] = "tool_calls"
                    log.info(f"Sync: Converted XML/Native tool call: {tool_name}({tool_args})")
            except Exception as e:
                log.error(f"Sync tool parse failed: {e}")

            log.info(f"Completions result: {result.get('choices', [{}])[0].get('message', {})}")
            return result

    except Exception as e:
        log.error(f"OpenAI compatible completion failed: {e}")
        raise HTTPException(500, str(e))


# ── WebSocket streaming ───────────────────────────────────────────────────────

@router.websocket("/stream")
async def chat_stream(websocket: WebSocket):
    """
    WebSocket endpoint for streaming chat responses with RAG + Citations.

    Accepts: {"type": "chat", "messages": [...], "model": "...", "session_id": "...", "use_rag": true}
    Sends:   {"type": "token", "token": "..."} |
             {"type": "done", "sync_status": {...}, "citations": [...]} |
             {"type": "error"}
    """
    await websocket.accept()
    log.info("DEBUG: WebSocket accepted, sending handshake...")
    # Send an initial handshake acknowledgment with a small delay to ensure client is ready
    try:
        await asyncio.sleep(0.1)
        await websocket.send_text(json.dumps({"type": "connected"}))
        log.info("DEBUG: Handshake sent")
    except Exception as e:
        log.error("Failed to send initial handshake", error=str(e))
        return

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

            # Multimodal: images as base64 data URLs, pre-extracted doc text
            ws_image_b64_list: list = data.get("images", [])  # ["data:image/png;base64,..."]
            ws_doc_text: str = data.get("doc_text", "")       # pre-extracted document text

            # Track user query for auto skill generation
            user_query = ""
            for msg in reversed(messages):
                if msg.get("role") == "user":
                    content = msg.get("content", "")
                    user_query = content if isinstance(content, str) else str(content)
                    break

            if use_voice and hasattr(websocket.app.state, "voice_service"):
                websocket.app.state.voice_service.stop()

            try:
                # 1. Truncate history to avoid context overflow
                if len(messages) > 10:
                    if messages[0].get("role") == "system":
                        messages = [messages[0]] + messages[-9:]
                    else:
                        messages = messages[-10:]

                # 2. RAG augmentation — ONE retrieve call, inject context directly
                rag_svc = getattr(websocket.app.state, "rag_service", None)
                rag_sources = []
                rag_context = ""
                use_agent = data.get("use_agent", False)
                if use_rag and rag_svc and rag_svc.is_ready and user_query and not use_agent:
                    try:
                        retrieval = await rag_svc.retrieve(user_query, top_k=5, max_tokens=1000)
                        rag_sources = retrieval.get("sources", [])
                        rag_context = retrieval.get("context", "")
                        if rag_context:
                            rag_sys = (
                                "## Retrieved Knowledge Context\n"
                                "The following is archived knowledge and past conversation logs. It is for reference ONLY.\n"
                                "DO NOT confuse this with the current active conversation.\n\n"
                                "<archived_context>\n"
                                f"{rag_context}\n"
                                "</archived_context>\n\n"
                                f"Sources found: {retrieval.get('total_results', 0)}"
                            )
                            if any(m.get("role") == "system" for m in messages):
                                messages = [
                                    {"role": "system", "content": rag_sys}
                                    if m.get("role") == "system" else m
                                    for m in messages
                                ]
                            else:
                                messages = [{"role": "system", "content": rag_sys}] + messages
                    except Exception as e:
                        log.debug(f"RAG augmentation skipped: {e}")

                if use_voice:
                    has_system = any(m.get("role") == "system" for m in messages)
                    if not has_system:
                        messages.insert(0, {
                            "role": "system",
                            "content": (
                                "You are Jarvis, a helpful voice assistant. "
                                "Respond in clear natural spoken sentences. "
                                "No markdown, no bullet points, no lists."
                            )
                        })

                # 3. Choose Inference Path: Multimodal → Agent → Direct
                full_response = []

                # ── Multimodal path ──────────────────────────────────────────────
                if ws_image_b64_list or ws_doc_text:
                    tmp_image_paths = []
                    try:
                        for b64_str in ws_image_b64_list:
                            if ',' in b64_str:
                                b64_str = b64_str.split(',', 1)[1]
                            img_bytes = base64.b64decode(b64_str)
                            tmp = tempfile.NamedTemporaryFile(
                                delete=False, suffix=".jpg", dir=str(_UPLOAD_DIR)
                            )
                            tmp.write(img_bytes)
                            tmp.close()
                            tmp_image_paths.append(tmp.name)

                        mm_prompt = user_query
                        if ws_doc_text:
                            mm_prompt = f"[Document Context]\n{ws_doc_text[:3000]}\n\n---\n{mm_prompt}"
                        if rag_context:
                            mm_prompt = f"## Knowledge Context\n{rag_context}\n\n---\n{mm_prompt}"

                        log.info(
                            "Starting multimodal stream",
                            images=len(tmp_image_paths),
                            has_doc=bool(ws_doc_text),
                            vision_ready=llm_svc.supports_vision,
                        )

                        async for token in llm_svc.stream_chat_multimodal(
                            text_prompt=mm_prompt,
                            image_paths=tmp_image_paths if llm_svc.supports_vision else [],
                            temperature=data.get("temperature", 0.7),
                            max_tokens=data.get("max_tokens", 2048),
                        ):
                            full_response.append(token)
                            if use_voice and hasattr(websocket.app.state, "voice_service"):
                                websocket.app.state.voice_service.process_token(token, voice_name)
                            await websocket.send_text(json.dumps({"type": "token", "token": token}))

                    finally:
                        for p in tmp_image_paths:
                            try:
                                os.unlink(p)
                            except Exception:
                                pass

                # ── Agentic path ───────────────────────────────────────────────
                if use_agent:
                    log.info("Starting agentic chat stream", messages_count=len(messages), model=model_name, rag=use_rag)
                    graph = build_chat_graph(llm_svc, rag_svc if use_rag else None)
                    try:
                        _tool_buffer = ""          # Buffer for <tool>...</tool> content
                        _in_tool_tag = False       # Are we inside a <tool> tag?

                        async for event in graph.astream_events(
                            {"messages": messages, "model": model_name, "session_id": session_id},
                            version="v2",
                            config={"recursion_limit": 50}
                        ):
                            kind = event["event"]
                            if kind == "on_chat_model_stream":
                                chunk = event["data"]["chunk"]
                                if hasattr(chunk, "content") and chunk.content and isinstance(chunk.content, str):
                                    token = chunk.content

                                    # ── Tool-tag filter ──────────────────────────────────
                                    # If the model is writing XML tool calls, buffer them.
                                    # Never stream raw <tool> JSON text to the UI.
                                    _tool_buffer += token

                                    if _in_tool_tag:
                                        # Keep buffering until closing tag or end-of-turn
                                        if any(t in _tool_buffer for t in ["</tool>", "</tool_code>", "<tool_call|>", "<|tool_call|>"]) or any(
                                            s in _tool_buffer for s in ["<|im_end|>", "<end_of_turn>", "<eos>"]
                                        ):
                                            if _tool_buffer.endswith(")") or _tool_buffer.endswith(")\n") or _tool_buffer.endswith("}\n") or any(t in _tool_buffer for t in ["</tool>", "</tool_code>", "<tool_call|>", "<|tool_call|>"]):
                                                _in_tool_tag = False
                                                _tool_buffer = ""  # Discard — graph will execute it
                                        continue  # Don't stream this to UI

                                    if any(t in _tool_buffer for t in ["<tool>", "<tool_code>", "<tool_call>", "<|tool_call>"]):
                                        _in_tool_tag = True
                                        first_tag = ""
                                        for tag in ["<tool>", "<tool_code>", "<tool_call>", "<|tool_call>"]:
                                            if tag in _tool_buffer:
                                                if not first_tag or _tool_buffer.find(tag) < _tool_buffer.find(first_tag):
                                                    first_tag = tag
                                        text_before = _tool_buffer.split(first_tag)[0]
                                        if text_before:
                                            full_response.append(text_before)
                                            if use_voice and hasattr(websocket.app.state, "voice_service"):
                                                websocket.app.state.voice_service.process_token(text_before, voice_name)
                                            await websocket.send_text(json.dumps({"type": "token", "token": text_before}))
                                        continue

                                    # Check if buffer ends with a partial match of "<tool>"
                                    is_partial = False
                                    for i in range(1, len("<tool>") + 1):
                                        if _tool_buffer.endswith("<tool>"[:i]):
                                            is_partial = True
                                            break
                                    
                                    if is_partial:
                                        continue  # hold buffer silently

                                    # ── Normal token ─────────────────────────────────────
                                    flush_text = _tool_buffer
                                    _tool_buffer = ""
                                    full_response.append(flush_text)
                                    if use_voice and hasattr(websocket.app.state, "voice_service"):
                                        websocket.app.state.voice_service.process_token(flush_text, voice_name)
                                    await websocket.send_text(json.dumps({"type": "token", "token": flush_text}))

                            elif kind == "on_tool_start":
                                tool_name = event.get("name", "tool")
                                tool_msg = f"\n\n🔧 **Running `{tool_name}`...**\n\n"
                                full_response.append(tool_msg)
                                await websocket.send_text(json.dumps({"type": "token", "token": tool_msg}))

                            elif kind == "on_tool_end":
                                tool_name = event.get("name", "tool")
                                result = event.get("data", {}).get("output", "")
                                
                                # LangGraph wraps outputs in a ToolMessage
                                if hasattr(result, "content"):
                                    result_str = str(result.content)[:300]
                                else:
                                    result_str = str(result)[:300] if result else ""
                                    
                                # Show a compact result inline
                                if result_str and not result_str.startswith("❌") and not "Error" in result_str:
                                    status = f"✅ `{tool_name}` done."
                                else:
                                    status = f"⚠️ `{tool_name}`: {result_str[:150]}"
                                result_msg = f"{status}\n\n"
                                full_response.append(result_msg)
                                await websocket.send_text(json.dumps({"type": "token", "token": result_msg}))

                    except Exception as graph_err:
                        log.error(f"Graph error: {graph_err}. Falling back to direct.")
                        use_agent = False # This will trigger the next 'if not use_agent' block

                # ── Direct fallback or standard path ──────────────────────────
                if not use_agent:
                    log.info("Starting direct LLM stream", messages_count=len(messages), model=model_name)
                    async for token in llm_svc.stream_chat(messages, model=model_name):
                        full_response.append(token)
                        if use_voice and hasattr(websocket.app.state, "voice_service"):
                            websocket.app.state.voice_service.process_token(token, voice_name)
                        await websocket.send_text(json.dumps({"type": "token", "token": token}))

                if use_voice and hasattr(websocket.app.state, "voice_service"):
                    websocket.app.state.voice_service.finalize_stream(voice_name)

                # 4. Build final response text and apply citations
                response_text = "".join(full_response)
                citations = []
                citation_svc = getattr(websocket.app.state, "citation_engine", None)
                if citation_svc and rag_sources and user_query:
                    response_text, citations = citation_svc.attach_citations(
                        response_text, rag_sources, user_query
                    )
                    # If citations were added, send them as a final token
                    if citations:
                        citation_block = response_text[len("".join(full_response)):]
                        if citation_block:
                            await websocket.send_text(json.dumps({
                                "type": "token",
                                "token": citation_block,
                            }))

                # 5. Track messages for KG sync
                if session_id:
                    user_msg = next((m for m in reversed(data.get("messages", [])) if m.get("role") == "user"), None)
                    if user_msg:
                        await _sync_message_to_kg(websocket.app.state, session_id, user_msg)

                    await _sync_message_to_kg(
                        websocket.app.state, session_id,
                        {"role": "assistant", "content": "".join(full_response)}
                    )

                # 6. Auto-generate skills from recent queries (background, non-blocking)
                if user_query and hasattr(websocket.app.state, "skills_service"):
                    skills_svc = websocket.app.state.skills_service
                    if skills_svc._auto_gen_enabled:
                        asyncio.create_task(
                            skills_svc.auto_generate_skills(recent_queries=[user_query])
                        )

                sync_status = {}
                if hasattr(websocket.app.state, "chat_sync_service"):
                    sync_status = websocket.app.state.chat_sync_service.get_sync_status()

                log.info("Chat stream complete")
                await websocket.send_text(json.dumps({
                    "type": "done",
                    "sync_status": sync_status,
                    "citations": citations,
                    "has_citations": len(citations) > 0,
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
