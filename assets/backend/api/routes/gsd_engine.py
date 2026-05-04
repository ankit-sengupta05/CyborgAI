"""
GSD Engine API Routes
PRD generation + phased execution with streaming progress.
"""
import json
import structlog
from fastapi import (
    APIRouter,
    Request,
    HTTPException,
    UploadFile,
    File,
    WebSocket,
    WebSocketDisconnect,
)
from pydantic import BaseModel

from services.gsd_engine import GSDEngine
from services.llm_service import LLMService

log = structlog.get_logger(__name__)
router = APIRouter()


class GeneratePRDRequest(BaseModel):
    description: str
    project_name: str


class ParsePRDRequest(BaseModel):
    prd_content: str
    project_name: str


@router.post("/generate-prd")
async def generate_prd(data: GeneratePRDRequest, request: Request):
    """Generate PRD from project description using LLM."""
    engine: GSDEngine = request.app.state.gsd_engine
    llm: LLMService = request.app.state.llm_service
    if not llm.is_ready:
        raise HTTPException(503, "LLM not ready. Load a model first.")
    prd = await engine.generate_prd(data.description, llm)
    return {"prd": prd, "project_name": data.project_name}


@router.post("/parse-prd")
async def parse_prd(data: ParsePRDRequest, request: Request):
    """Parse PRD text into an execution plan."""
    engine: GSDEngine = request.app.state.gsd_engine
    llm: LLMService = request.app.state.llm_service
    if not llm.is_ready:
        raise HTTPException(503, "LLM not ready.")
    plan = await engine.parse_prd_into_steps(data.prd_content, data.project_name, llm)
    return plan.model_dump()


@router.post("/upload-prd")
async def upload_prd(request: Request, file: UploadFile = File(...)):
    """Upload a PRD file (.md, .txt, .docx, .pdf)."""
    import tempfile
    import os
    from pathlib import Path
    from services.utils.text_extractor import extract_text

    # Save to temp file to process
    with tempfile.NamedTemporaryFile(delete=False, suffix=Path(file.filename).suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        prd_text = await extract_text(tmp_path)
        project_name = file.filename.rsplit(".", 1)[0]

        engine: GSDEngine = request.app.state.gsd_engine
        llm: LLMService = request.app.state.llm_service
        if not llm.is_ready:
            raise HTTPException(503, "LLM not ready.")

        plan = await engine.parse_prd_into_steps(prd_text, project_name, llm)
        return plan.model_dump()
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


@router.get("/plans")
async def list_plans(request: Request):
    engine: GSDEngine = request.app.state.gsd_engine
    return {"plans": engine.list_plans()}


@router.get("/plans/{plan_id}")
async def get_plan(plan_id: str, request: Request):
    engine: GSDEngine = request.app.state.gsd_engine
    plan = engine.get_plan(plan_id)
    if not plan:
        raise HTTPException(404, "Plan not found")
    return plan


@router.get("/plans/{plan_id}/tree")
async def get_progress_tree(plan_id: str, request: Request):
    engine: GSDEngine = request.app.state.gsd_engine
    tree = engine.get_progress_tree(plan_id)
    if not tree:
        raise HTTPException(404, "Plan not found")
    return tree


@router.post("/plans/{plan_id}/pause")
async def pause_plan(plan_id: str, request: Request):
    engine: GSDEngine = request.app.state.gsd_engine
    await engine.pause_plan(plan_id)
    return {"status": "paused"}


@router.websocket("/plans/{plan_id}/execute")
async def execute_plan_ws(plan_id: str, websocket: WebSocket):
    """
    Execute plan via WebSocket — streams step-by-step progress.
    Client receives: step_start, step_done, plan_done events.
    """
    await websocket.accept()
    engine: GSDEngine = websocket.app.state.gsd_engine
    llm: LLMService = websocket.app.state.llm_service

    if not llm.is_ready:
        await websocket.send_text(json.dumps({
            "type": "error",
            "message": "LLM not ready. Load a model first.",
        }))
        await websocket.close()
        return

    try:
        async for update in engine.execute_plan(plan_id, llm):
            await websocket.send_text(json.dumps(update))
    except WebSocketDisconnect:
        await engine.pause_plan(plan_id)
    except Exception as e:
        log.error(f"Execution error: {e}")
        try:
            await websocket.send_text(json.dumps({
                "type": "error", "message": str(e)
            }))
        except Exception:
            pass


@router.post("/plans/{plan_id}/debug")
async def debug_project(plan_id: str, request: Request):
    """Start automatic debug and fix process."""
    engine: GSDEngine = request.app.state.gsd_engine
    llm: LLMService = request.app.state.llm_service

    plan = engine.get_plan(plan_id)
    if not plan:
        raise HTTPException(404, "Plan not found")

    workspace = engine.workspaces_dir / plan_id
    from services.debug_engine import DebugEngine
    dbg = DebugEngine(workspace)

    issues = await dbg.run_diagnostics()

    # Auto-fix all issues
    for issue in issues:
        await dbg.auto_fix(issue, llm)

    return {"status": "debug_complete", "issues_fixed": len(issues)}


@router.get("/plans/{plan_id}/files")
async def list_workspace_files(plan_id: str, request: Request):
    engine: GSDEngine = request.app.state.gsd_engine
    files = engine.list_workspace_files(plan_id)
    return {"files": files}


@router.get("/plans/{plan_id}/file")
async def get_workspace_file(plan_id: str, path: str, request: Request):
    engine: GSDEngine = request.app.state.gsd_engine
    workspace = engine.workspaces_dir / plan_id
    file_path = workspace / path

    if not file_path.exists() or not str(file_path.resolve()).startswith(str(workspace.resolve())):
        raise HTTPException(404, "File not found")

    try:
        content = file_path.read_text(encoding="utf-8", errors="ignore")
        return {
            "content": content,
            "path": path,
            "filename": file_path.name,
            "extension": file_path.suffix
        }
    except Exception as e:
        raise HTTPException(500, f"Error reading file: {e}")
