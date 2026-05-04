"""
Agents API Routes — LangGraph deep agent orchestration
"""
import asyncio
import uuid
import structlog
from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel

from agents.graphs.chat_graph import build_chat_graph
from langchain_core.messages import HumanMessage

log = structlog.get_logger(__name__)
router = APIRouter()

# In-memory agent run tracker
_agent_runs: dict[str, dict] = {}


class AgentRunRequest(BaseModel):
    task: str
    agent_type: str = "chat"  # chat | code | research | file
    context: dict = {}
    max_steps: int = 10


@router.post("/run")
async def run_agent(data: AgentRunRequest, request: Request):
    """Start an agent run."""
    run_id = str(uuid.uuid4())
    llm_svc = request.app.state.llm_service

    if not llm_svc.is_ready:
        raise HTTPException(503, "LLM not loaded")

    _agent_runs[run_id] = {"status": "running", "steps": [], "output": None}

    # Run in background
    asyncio.create_task(_run_agent_task(run_id, data, llm_svc))

    return {"run_id": run_id, "status": "started"}


async def _run_agent_task(run_id: str, data: AgentRunRequest, llm_svc):
    try:
        graph = build_chat_graph(llm_svc)
        result = await graph.ainvoke({
            "messages": [HumanMessage(content=data.task)],
            "model": llm_svc.current_model or "local",
            "session_id": run_id,
            "output": "",
            "usage": {},
        })
        _agent_runs[run_id] = {
            "status": "completed",
            "output": result.get("output", ""),
            "steps": [str(m) for m in result.get("messages", [])],
        }
    except Exception as e:
        _agent_runs[run_id] = {"status": "error", "error": str(e)}


@router.get("/status/{run_id}")
async def agent_status(run_id: str):
    run = _agent_runs.get(run_id)
    if not run:
        raise HTTPException(404, "Run not found")
    return run


@router.post("/stop/{run_id}")
async def stop_agent(run_id: str):
    run = _agent_runs.get(run_id)
    if run:
        run["status"] = "stopped"
    return {"stopped": run_id}
