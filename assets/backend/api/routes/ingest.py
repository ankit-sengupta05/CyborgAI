"""
Ingest API — job-based ingestion: files, folders, YouTube transcripts.
Fixed: proper error handling (no raw 500s), async job tracking,
       folder ingestion runs in background.
"""
import asyncio
import uuid
import structlog
from fastapi import APIRouter, Request, BackgroundTasks, HTTPException
from pydantic import BaseModel

from services.graph_service import GraphService

log = structlog.get_logger(__name__)
router = APIRouter()

# In-memory job tracker  {job_id: {status, progress, file, total, done, failed, logs}}
_jobs: dict[str, dict] = {}


class IngestPathRequest(BaseModel):
    path: str


class IngestYouTubeRequest(BaseModel):
    url: str


# ─── Core Routes ──────────────────────────────────────────────────────────────

@router.post("/")
async def ingest_path(
    data: IngestPathRequest,
    background_tasks: BackgroundTasks,
    request: Request,
):
    """Ingest a file or folder. Returns immediately with a job_id."""
    from pathlib import Path
    svc: GraphService = request.app.state.graph_service
    path = Path(data.path)

    if not path.exists():
        raise HTTPException(404, f"Path not found: {data.path}")

    job_id = str(uuid.uuid4())[:8]
    _jobs[job_id] = {
        "status": "running",
        "path": str(path),
        "name": path.name,
        "progress": 0.0,
        "current_file": "",
        "total": 0,
        "done": 0,
        "failed": 0,
        "nodes_created": 0,
        "logs": [],
    }

    background_tasks.add_task(_run_ingest, job_id, svc, path)
    return {"job_id": job_id, "status": "running", "path": str(path)}


@router.get("/jobs")
async def list_jobs():
    """Return all current and recent ingestion jobs."""
    return {"jobs": list(_jobs.values())}


@router.get("/jobs/{job_id}")
async def get_job(job_id: str):
    job = _jobs.get(job_id)
    if not job:
        raise HTTPException(404, f"Job {job_id} not found")
    return job


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
            "or yt-dlp/youtube-transcript-api may not be installed.",
        )

    import tempfile, os
    video_id = _extract_video_id(url)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False,
        prefix=f"yt_{video_id}_", encoding="utf-8",
    ) as f:
        f.write(f"YouTube Transcript: {url}\n\n{transcript}")
        tmp_path = f.name

    try:
        result = await svc.ingest_file(tmp_path)
        result["source_url"] = url
        result["video_id"] = video_id
        return result
    except Exception as e:
        log.error(f"YouTube ingest failed: {e}")
        raise HTTPException(500, f"Ingest failed: {str(e)}")
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


# ─── Background job runner ────────────────────────────────────────────────────

async def _run_ingest(job_id: str, svc: GraphService, path):
    """Run ingestion in background, updating job state."""
    from pathlib import Path

    job = _jobs[job_id]
    try:
        if path.is_dir():
            await _ingest_dir_with_progress(job_id, svc, path)
        else:
            job["current_file"] = path.name
            job["total"] = 1
            result = await svc.ingest_file(str(path))
            job["nodes_created"] = result.get("nodes_created", 0)
            job["done"] = 1
            job["progress"] = 1.0
            job["logs"].append(f"[OK] {path.name} → {result.get('nodes_created', 0)} nodes")

        job["status"] = "done"
        log.info(f"[Ingest job {job_id}] complete")

    except Exception as e:
        job["status"] = "failed"
        job["logs"].append(f"[ERROR] {str(e)}")
        log.error(f"[Ingest job {job_id}] failed: {e}")


async def _ingest_dir_with_progress(job_id: str, svc: GraphService, dir_path):
    from pathlib import Path

    supported = {
        ".txt", ".md", ".py", ".js", ".ts", ".json",
        ".html", ".css", ".pdf", ".docx", ".pptx", ".csv",
        ".png", ".jpg", ".jpeg", ".webp",
    }
    files = [
        f for f in dir_path.rglob("*")
        if f.is_file() and f.suffix.lower() in supported
    ]

    job = _jobs[job_id]
    job["total"] = len(files)
    nodes_total = 0

    for i, file_path in enumerate(files):
        job["current_file"] = file_path.name
        job["progress"] = i / max(len(files), 1)
        try:
            result = await svc.ingest_file(str(file_path))
            nc = result.get("nodes_created", 0)
            nodes_total += nc
            job["done"] += 1
            job["logs"].append(f"[OK] {file_path.name} → {nc} nodes")
        except Exception as e:
            job["failed"] += 1
            job["logs"].append(f"[ERR] {file_path.name}: {str(e)[:120]}")
            log.warning(f"[Ingest] Failed {file_path.name}: {e}")

        job["nodes_created"] = nodes_total

    job["progress"] = 1.0


# ─── YouTube helpers ──────────────────────────────────────────────────────────

async def _extract_transcript(url: str) -> str:
    loop = asyncio.get_event_loop()
    video_id = _extract_video_id(url)
    if not video_id:
        return ""

    try:
        transcript = await loop.run_in_executor(None, _fetch_via_api, video_id)
        if transcript:
            return transcript
    except Exception as e:
        log.debug(f"youtube-transcript-api failed: {e}")

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
    import subprocess, tempfile, os, glob, json
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            ["yt-dlp", "--write-auto-sub", "--sub-lang", "en",
             "--skip-download", "--sub-format", "json3",
             "-o", os.path.join(tmpdir, "%(id)s.%(ext)s"), url],
            capture_output=True, text=True, timeout=60,
        )
        json_files = glob.glob(os.path.join(tmpdir, "*.json3"))
        if json_files:
            with open(json_files[0], encoding="utf-8") as f:
                data = json.load(f)
            texts = [
                seg.get("utf8", "")
                for event in data.get("events", [])
                for seg in event.get("segs", [])
            ]
            return " ".join(texts).strip()
    return ""


def _extract_video_id(url: str) -> str:
    import re
    for p in [r'(?:v=|/v/|youtu\.be/|/embed/|/shorts/)([a-zA-Z0-9_-]{11})']:
        m = re.search(p, url)
        if m:
            return m.group(1)
    return ""
