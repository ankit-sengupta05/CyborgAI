"""
Knowledge Graph API Routes
"""
import tempfile
import os
from fastapi import APIRouter, Request, UploadFile, File
from pydantic import BaseModel

from services.graph_service import GraphService

router = APIRouter()


class IngestRequest(BaseModel):
    path: str


@router.get("/nodes")
async def get_nodes(request: Request):
    svc: GraphService = request.app.state.graph_service
    nodes, _ = await svc.get_all()
    return {"nodes": nodes, "total": len(nodes)}


@router.get("/edges")
async def get_edges(request: Request):
    svc: GraphService = request.app.state.graph_service
    _, edges = await svc.get_all()
    return {"edges": edges, "total": len(edges)}


@router.post("/ingest")
async def ingest(data: IngestRequest, request: Request):
    svc: GraphService = request.app.state.graph_service
    result = await svc.ingest_file(data.path)
    return result


@router.post("/ingest/upload")
async def ingest_upload(request: Request, file: UploadFile = File(...)):
    """Upload and ingest a file directly."""
    svc: GraphService = request.app.state.graph_service
    suffix = os.path.splitext(file.filename or "file.txt")[1]
    content = await file.read()
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(content)
        tmp_path = tmp.name
    try:
        result = await svc.ingest_file(tmp_path)
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
    return result


@router.get("/search")
async def search(q: str, limit: int = 20, request: Request = None):
    svc: GraphService = request.app.state.graph_service
    results = await svc.search(q, limit=limit)
    return {"results": results, "total": len(results)}


@router.get("/communities")
async def get_communities(request: Request):
    svc: GraphService = request.app.state.graph_service
    nodes, _, meta = await svc.get_all()
    community_map: dict[int, int] = {}
    for n in nodes:
        c = n.get("community", 0)
        community_map[c] = community_map.get(c, 0) + 1

    communities = []
    for cid, count in sorted(community_map.items()):
        m = meta.get(cid, {"name": f"Cluster {cid}", "summary": "Automatic cluster"})
        communities.append({
            "id": cid,
            "nodeCount": count,
            "name": m.get("name"),
            "summary": m.get("summary")
        })
    return {"communities": communities}


@router.get("/full")
async def get_full_graph(request: Request):
    svc: GraphService = request.app.state.graph_service
    nodes, edges, meta = await svc.get_all()

    # Enrich communities
    community_map: dict[int, int] = {}
    for n in nodes:
        c = n.get("community", 0)
        community_map[c] = community_map.get(c, 0) + 1

    communities = []
    for cid, count in sorted(community_map.items()):
        m = meta.get(cid, {"name": f"Cluster {cid}", "summary": "Automatic cluster"})
        communities.append({
            "id": cid,
            "nodeCount": count,
            "name": m.get("name"),
            "summary": m.get("summary")
        })

    return {
        "nodes": nodes,
        "edges": edges,
        "communities": communities
    }


@router.delete("/clear")
async def clear_graph(request: Request):
    svc: GraphService = request.app.state.graph_service
    await svc.clear_graph()
    return {"status": "ok", "message": "Knowledge graph cleared"}
