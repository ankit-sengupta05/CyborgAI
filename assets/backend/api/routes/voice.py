import json
import asyncio
from fastapi import APIRouter, Request, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Optional
import structlog

from services.voice_service import VOICES_CATALOGUE

log = structlog.get_logger(__name__)
router = APIRouter()


@router.get("/voices")
async def get_voices():
    """List all available voices."""
    return VOICES_CATALOGUE


@router.get("/status")
async def get_status(request: Request):
    """Check if voice service is ready."""
    voice_svc = request.app.state.voice_service
    if not voice_svc:
        return {"ready": False, "status": "missing"}
    status = "ready" if voice_svc.is_ready else "initializing"
    return {"ready": voice_svc.is_ready, "status": status}


class SpeakRequest(BaseModel):
    text: str
    voice: Optional[str] = "af_sarah"


@router.post("/speak")
async def speak(request: Request, data: SpeakRequest):
    """Enqueue text for TTS synthesis and playback."""
    voice_svc = request.app.state.voice_service
    if not voice_svc or not voice_svc.is_ready:
        raise HTTPException(status_code=503, detail="Voice service still initializing")

    voice_svc.speak(data.text, data.voice)
    return {"status": "enqueued", "text": data.text}


@router.post("/listen")
async def listen(request: Request):
    """Start listening and return transcription."""
    voice_svc = request.app.state.voice_service
    if not voice_svc or not voice_svc.is_ready:
        raise HTTPException(status_code=503, detail="Voice service still initializing")

    transcript = await voice_svc.listen_and_transcribe()
    return {"transcript": transcript}


@router.post("/stop")
async def stop(request: Request):
    """Stop all audio playback."""
    voice_svc = request.app.state.voice_service
    if voice_svc:
        voice_svc.stop()
    return {"status": "stopped"}


@router.post("/test")
async def test_voice(request: Request):
    """Run a quick audio system check."""
    voice_svc = request.app.state.voice_service
    if not voice_svc or not voice_svc.is_ready:
        raise HTTPException(status_code=503, detail="Voice service still initializing")

    test_text = "Hello, I am Jarvis. System check complete. Audio output is working correctly."
    voice_svc.speak(test_text, "af_heart")
    return {"status": "testing", "message": test_text}


@router.websocket("/stream")
async def voice_stream(websocket: WebSocket):
    """
    WebSocket for voice events and wake word notifications.
    """
    await websocket.accept()
    loop = asyncio.get_event_loop()
    voice_svc = websocket.app.state.voice_service

    def on_wake(transcript):
        asyncio.run_coroutine_threadsafe(
            websocket.send_text(json.dumps({
                "type": "wake_word_detected",
                "transcript": transcript
            })),
            loop
        )

    try:
        while True:
            raw = await websocket.receive_text()
            data = json.loads(raw)

            if data.get("type") == "start_wake_word":
                voice_svc.start_wake_word_listener(on_wake)
                await websocket.send_text(json.dumps({"type": "status", "listening": True}))

            elif data.get("type") == "stop_wake_word":
                voice_svc.stop_wake_word_listener()
                await websocket.send_text(json.dumps({"type": "status", "listening": False}))

    except WebSocketDisconnect:
        voice_svc.stop_wake_word_listener()
    except Exception as e:
        log.error("Voice WebSocket error", error=str(e))
