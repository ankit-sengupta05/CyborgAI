"""
GSD (Get Shit Done) API Routes — Phased project management
"""
import uuid
from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
from typing import Optional

from services.database import GSDProjectDB, get_db

router = APIRouter()


class ProjectCreate(BaseModel):
    name: str
    description: str = ""


class TaskCreate(BaseModel):
    title: str
    phase: str = "plan"
    description: str = ""
    priority: int = 1
    tags: list[str] = []


class TaskUpdate(BaseModel):
    status: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[int] = None
    phase: Optional[str] = None


@router.get("/projects")
async def list_projects(request: Request):
    user_id = getattr(request.state, "user_id", "local")
    async with get_db() as db:
        projects = await GSDProjectDB.get_by_user(db, user_id)
    return {"projects": [p.to_dict() for p in projects]}


@router.post("/projects")
async def create_project(data: ProjectCreate, request: Request):
    user_id = getattr(request.state, "user_id", "local")
    async with get_db() as db:
        project = await GSDProjectDB.create(db, user_id, data.name, data.description)
    return project.to_dict()


@router.get("/projects/{project_id}")
async def get_project(project_id: str, request: Request):
    async with get_db() as db:
        project = await GSDProjectDB.get(db, project_id)
    if not project:
        raise HTTPException(404, "Project not found")
    return project.to_dict()


@router.post("/projects/{project_id}/tasks")
async def create_task(project_id: str, data: TaskCreate, request: Request):
    async with get_db() as db:
        project = await GSDProjectDB.get(db, project_id)
        if not project:
            raise HTTPException(404, "Project not found")

        task = {
            "id": str(uuid.uuid4()),
            "title": data.title,
            "description": data.description,
            "phase": data.phase,
            "status": "todo",
            "priority": data.priority,
            "tags": data.tags,
        }

        tasks = list(project.tasks or [])
        tasks.append(task)
        project.tasks = tasks
        await db.flush()

    return task


@router.patch("/projects/{project_id}/tasks/{task_id}")
async def update_task(project_id: str, task_id: str,
                      data: TaskUpdate, request: Request):
    async with get_db() as db:
        project = await GSDProjectDB.get(db, project_id)
        if not project:
            raise HTTPException(404, "Project not found")

        tasks = list(project.tasks or [])
        updated_task = None
        for i, task in enumerate(tasks):
            if task["id"] == task_id:
                if data.status is not None:
                    task["status"] = data.status
                if data.title is not None:
                    task["title"] = data.title
                if data.description is not None:
                    task["description"] = data.description
                if data.priority is not None:
                    task["priority"] = data.priority
                if data.phase is not None:
                    task["phase"] = data.phase
                tasks[i] = task
                updated_task = task
                break

        if not updated_task:
            raise HTTPException(404, "Task not found")

        project.tasks = tasks
        await db.flush()

    return updated_task


@router.delete("/projects/{project_id}/tasks/{task_id}")
async def delete_task(project_id: str, task_id: str, request: Request):
    async with get_db() as db:
        project = await GSDProjectDB.get(db, project_id)
        if not project:
            raise HTTPException(404, "Project not found")
        project.tasks = [t for t in (project.tasks or []) if t["id"] != task_id]
        await db.flush()
    return {"deleted": task_id}


@router.delete("/projects/{project_id}")
async def delete_project(project_id: str, request: Request):
    async with get_db() as db:
        project = await GSDProjectDB.get(db, project_id)
        if not project:
            raise HTTPException(404, "Project not found")
        await db.delete(project)
    return {"deleted": project_id}
