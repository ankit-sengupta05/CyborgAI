"""
Vault API Routes — Markdown file management for AI-OS
"""
from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
from typing import Optional

from services.vault_service import VaultService, VAULT_DIRS

router = APIRouter()


class NoteCreate(BaseModel):
    title: str
    content: str = ""
    folder: str = "inbox"
    tags: list[str] = []
    note_type: str = "note"
    project: str = ""
    area: str = ""


class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    tags: Optional[list[str]] = None
    frontmatter_update: Optional[dict] = None


class NoteMove(BaseModel):
    target_folder: str


@router.get("/notes")
async def list_notes(folder: str = None, tag: str = None, request: Request = None):
    svc: VaultService = request.app.state.vault_service
    notes = await svc.list_notes(folder=folder, tag=tag)
    return {"notes": notes, "total": len(notes)}


@router.get("/notes/search")
async def search_notes(q: str, request: Request = None):
    svc: VaultService = request.app.state.vault_service
    results = await svc.search_notes(q)
    return {"results": results, "total": len(results)}


@router.get("/notes/graph")
async def get_graph(request: Request):
    svc: VaultService = request.app.state.vault_service
    return await svc.get_graph_data()


@router.get("/notes/{note_id}")
async def get_note(note_id: str, request: Request):
    svc: VaultService = request.app.state.vault_service
    note = await svc.get_note(note_id)
    if not note:
        raise HTTPException(404, "Note not found")
    return note


@router.post("/notes")
async def create_note(data: NoteCreate, request: Request):
    svc: VaultService = request.app.state.vault_service
    note = await svc.create_note(
        title=data.title, content=data.content,
        folder=data.folder, tags=data.tags,
        note_type=data.note_type, project=data.project, area=data.area,
    )
    return note


@router.patch("/notes/{note_id}")
async def update_note(note_id: str, data: NoteUpdate, request: Request):
    svc: VaultService = request.app.state.vault_service
    note = await svc.update_note(
        note_id, title=data.title, content=data.content,
        tags=data.tags, frontmatter_update=data.frontmatter_update,
    )
    if not note:
        raise HTTPException(404, "Note not found")
    return note


@router.delete("/notes/{note_id}")
async def delete_note(note_id: str, request: Request):
    svc: VaultService = request.app.state.vault_service
    ok = await svc.delete_note(note_id)
    if not ok:
        raise HTTPException(404, "Note not found")
    return {"deleted": note_id}


@router.post("/notes/{note_id}/move")
async def move_note(note_id: str, data: NoteMove, request: Request):
    svc: VaultService = request.app.state.vault_service
    note = await svc.move_note(note_id, data.target_folder)
    if not note:
        raise HTTPException(404, "Note not found")
    return note


@router.get("/folders")
async def list_folders():
    return {"folders": [{"key": k, "name": v} for k, v in VAULT_DIRS.items()]}
