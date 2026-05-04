"""
Ingest API — job-based ingestion: files, folders, YouTube transcripts.
"""
import asyncio
import structlog
from fastapi import APIRouter, Request, BackgroundTasks, HTTPException
from pydantic import BaseModel

from services.graph_service import GraphService

log = structlog.get_logger(__name__)
router = APIRouter()

# In-memory job tracker
_jobs: dict[str, dict] = {}


class IngestPathRequest(BaseModel):
    path: str


class IngestYouTubeRequest(BaseModel):
    url: str


@router.post("/")
async def ingest_path(data: IngestPathRequest, background_tasks: BackgroundTasks,
                      request: Request):
    """Ingest a file or folder into the knowledge graph."""
    svc: GraphService = request.app.state.graph_service
    result = await svc.ingest_file(data.path)
    return result


@router.post("/youtube")
async def ingest_youtube(data: IngestYouTubeRequest, request: Request):
    """
    Extract transcript from a YouTube video and ingest into knowledge graph.
    Uses yt-dlp (if available) or youtube-transcript-api as fallback.
    """
    svc: GraphService = request.app.state.graph_service
    url = data.url.strip()

    transcript = await _extract_transcript(url)
    if not transcript:
        raise HTTPException(
            400,
            "Could not extract transcript. The video may have no captions, "
            "or yt-dlp/youtube-transcript-api may not be installed."
        )

    # Write to a temp file and ingest
    import tempfile
    import os
    video_id = _extract_video_id(url)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False,
        prefix=f"yt_{video_id}_", encoding="utf-8"
    ) as f:
        f.write(f"YouTube Transcript: {url}\n\n{transcript}")
        tmp_path = f.name

    try:
        result = await svc.ingest_file(tmp_path)
        result["source_url"] = url
        result["video_id"] = video_id
        return result
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


async def _extract_transcript(url: str) -> str:
    """Try multiple methods to get transcript."""
    loop = asyncio.get_event_loop()
    video_id = _extract_video_id(url)
    if not video_id:
        return ""

    # Method 1: youtube-transcript-api (pip install youtube-transcript-api)
    try:
        transcript = await loop.run_in_executor(None, _fetch_via_api, video_id)
        if transcript:
            return transcript
    except Exception as e:
        log.debug(f"youtube-transcript-api failed: {e}")

    # Method 2: yt-dlp subtitles (pip install yt-dlp)
    try:
        transcript = await loop.run_in_executor(None, _fetch_via_ytdlp, url)
        if transcript:
            return transcript
    except Exception as e:
        log.debug(f"yt-dlp failed: {e}")

    return ""


def _fetch_via_api(video_id: str) -> str:
    from youtube_transcript_api import YouTubeTranscriptApi
    transcript_list = YouTubeTranscriptApi.get_transcript(video_id)
    return " ".join(t["text"] for t in transcript_list)


def _fetch_via_ytdlp(url: str) -> str:
    import subprocess
    import tempfile
    import os
    import glob
    import json
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run([
            "yt-dlp", "--write-auto-sub", "--sub-lang", "en",
            "--skip-download", "--sub-format", "json3",
            "-o", os.path.join(tmpdir, "%(id)s.%(ext)s"), url
        ], capture_output=True, text=True, timeout=60)
        json_files = glob.glob(os.path.join(tmpdir, "*.json3"))
        if json_files:
            with open(json_files[0], encoding="utf-8") as f:
                data = json.load(f)
            texts = []
            for event in data.get("events", []):
                for seg in event.get("segs", []):
                    texts.append(seg.get("utf8", ""))
            return " ".join(texts).strip()
    return ""


def _extract_video_id(url: str) -> str:
    import re
    patterns = [
        r'(?:v=|/v/|youtu\.be/|/embed/|/shorts/)([a-zA-Z0-9_-]{11})',
    ]
    for p in patterns:
        m = re.search(p, url)
        if m:
            return m.group(1)
    return ""
