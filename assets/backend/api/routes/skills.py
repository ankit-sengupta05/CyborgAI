"""
Skills API Routes — CRUD + execution + dynamic creation + auto-generation.
"""
import asyncio
import uuid
import tempfile
import os
import structlog
from fastapi import APIRouter, Request, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import Optional

log = structlog.get_logger(__name__)
router = APIRouter()


class SkillExecuteRequest(BaseModel):
    name: str
    parameters: dict = {}


class SkillCreateRequest(BaseModel):
    task_description: str
    skill_name: Optional[str] = None


class SkillAutoGenRequest(BaseModel):
    context: str = ""
    recent_queries: list[str] = []


class SkillToggleAutoGenRequest(BaseModel):
    enabled: bool = True


@router.get("/")
async def list_skills(request: Request):
    """List all registered skills."""
    svc = request.app.state.skills_service
    skills = svc.get_all_skills()
    return {"skills": skills, "total": len(skills)}


@router.get("/categories")
async def list_skill_categories(request: Request):
    """List skills grouped by category."""
    svc = request.app.state.skills_service
    skills = svc.get_all_skills()
    categories: dict[str, list] = {}
    for skill in skills:
        cat = skill.get("category", "general")
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(skill)
    return {"categories": categories, "total_skills": len(skills)}


@router.get("/{name}")
async def get_skill(name: str, request: Request):
    """Get a specific skill by name."""
    svc = request.app.state.skills_service
    skill = svc.get_skill(name)
    if not skill:
        raise HTTPException(404, f"Skill '{name}' not found")
    return skill


@router.delete("/{name}")
async def delete_skill(name: str, request: Request):
    """Delete a specific skill by name."""
    svc = request.app.state.skills_service
    success = svc.delete_skill(name)
    if not success:
        raise HTTPException(404, f"Skill '{name}' not found")
    return {"status": "deleted", "skill": name}


@router.post("/execute")
async def execute_skill(data: SkillExecuteRequest, request: Request):
    """Execute a registered skill."""
    svc = request.app.state.skills_service
    result = await svc.execute_skill(data.name, data.parameters)
    return result


@router.post("/create")
async def create_skill(data: SkillCreateRequest, request: Request):
    """
    Create a new skill dynamically from a task description.

    The system will:
    1. Generate Python code from the description
    2. Test the module
    3. Debug and fix errors (up to 5 iterations)
    4. Register the skill as an active tool
    """
    svc = request.app.state.skills_service
    result = await svc.create_skill(
        task_description=data.task_description,
        skill_name=data.skill_name,
    )
    return result.to_dict()


@router.post("/auto-generate")
async def auto_generate_skills(data: SkillAutoGenRequest, request: Request):
    """
    Auto-detect missing capabilities and generate new skills.

    Analyses the provided context + recent queries using the LLM to identify
    1-3 automation tasks that would benefit from a reusable skill, then
    creates and registers each one.
    """
    svc = request.app.state.skills_service
    created = await svc.auto_generate_skills(
        context=data.context,
        recent_queries=data.recent_queries,
    )
    return {
        "status": "ok",
        "created": created,
        "count": len(created),
    }


@router.post("/auto-generate/toggle")
async def toggle_auto_generation(data: SkillToggleAutoGenRequest, request: Request):
    """Enable or disable automatic skill generation."""
    svc = request.app.state.skills_service
    svc.enable_auto_generation(data.enabled)
    return {"status": "ok", "auto_generation_enabled": data.enabled}


@router.get("/sync/status")
async def get_sync_status(request: Request):
    """Get chat sync status."""
    if hasattr(request.app.state, "chat_sync_service"):
        return request.app.state.chat_sync_service.get_sync_status()
    return {"running": False, "pending_messages": 0}


@router.post("/sync/now")
async def trigger_sync(request: Request):
    """Manually trigger chat-to-KG sync."""
    if hasattr(request.app.state, "chat_sync_service"):
        await request.app.state.chat_sync_service.sync_all_pending()
        return {"status": "synced", "message": "All pending chats synced to knowledge graph"}
    raise HTTPException(503, "Chat sync service not available")
