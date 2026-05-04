"""
GitHub Integration API Routes
Secure token storage + repo management.
"""
import structlog
from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel

from config.settings import settings

log = structlog.get_logger(__name__)
router = APIRouter()

# Persistent config path
CONFIG_PATH = settings.data_dir / "github_config.json"

# Vault directories are now managed by GitHubService


# Helper methods moved to GitHubService


class ConnectRequest(BaseModel):
    token: str


class SyncRequest(BaseModel):
    repo: str


class CreateVaultRequest(BaseModel):
    name: str
    private: bool = True


@router.get("/status")
async def status(request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    state = svc.state.get(user_id, {"connected": False})

    return {
        "connected": state.get("connected", False),
        "username": state.get("username"),
        "avatar_url": state.get("avatar_url"),
        "vault_repo": state.get("vault_repo"),
        "last_error": state.get("last_error"),
    }


@router.post("/connect")
async def connect(data: ConnectRequest, request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    try:
        state = await svc.connect(user_id, data.token)
        log.info(f"GitHub connected for {state['username']}")
        return {
            "connected": True,
            "username": state["username"],
            "avatar_url": state["avatar_url"],
            "vault_repo": state["vault_repo"]
        }
    except Exception as e:
        raise HTTPException(401, f"GitHub authentication failed: {e}")


@router.get("/repos")
async def list_repos(request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    state = svc.state.get(user_id, {})
    if not state.get("connected"):
        raise HTTPException(401, "GitHub not connected")
# ... (keeps rest of list_repos as it uses 'state' which we just got from svc)

    try:
        gh = state["gh"]
        user = gh.get_user()
        repos = []
        for repo in user.get_repos(affiliation="owner,collaborator", sort="updated"):
            if not repo.permissions.admin:
                continue
            if len(repos) >= 50:
                break

            repos.append({
                "name": repo.name,
                "full_name": repo.full_name,
                "description": repo.description or "",
                "private": repo.private,
                "html_url": repo.html_url,
                "stargazers_count": repo.stargazers_count,
                "language": repo.language or "Unknown",
                "updated_at": repo.updated_at.isoformat() if repo.updated_at else None,
                "permissions": {
                    "admin": repo.permissions.admin,
                    "push": repo.permissions.push,
                    "pull": repo.permissions.pull,
                }
            })
        return {"repos": repos}
    except Exception as e:
        raise HTTPException(500, f"Failed to fetch repos: {e}")


@router.post("/vault/set")
async def set_vault(data: SyncRequest, request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service

    success = await svc.set_vault_repo(user_id, data.repo)
    if not success:
        raise HTTPException(401, "GitHub not connected")

    log.info(f"Vault set to {data.repo}")
    return {"status": "vault_set", "repo": data.repo}


@router.post("/vault/create")
async def create_vault(data: CreateVaultRequest, request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    state = svc.state.get(user_id, {})
    if not state.get("connected"):
        raise HTTPException(401, "GitHub not connected")

    try:
        gh = state["gh"]
        user = gh.get_user()
        repo = user.create_repo(
            data.name,
            description="Cyborg AI OS Vault - Second Brain",
            private=data.private,
            auto_init=True,
        )
        await svc.set_vault_repo(user_id, repo.full_name)
        return {"status": "vault_created", "repo": repo.full_name}
    except Exception as e:
        raise HTTPException(500, f"Failed to create vault: {e}")


@router.post("/sync")
async def sync_repo(data: SyncRequest, request: Request):
    """Trigger manual sync."""
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service

    await svc.pull_vault(user_id)
    await svc.force_sync(user_id)

    return {"status": "sync_triggered"}


@router.get("/repos/{owner}/{repo}/contents")
async def list_repo_contents(owner: str, repo: str, request: Request, path: str = ""):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    state = svc.state.get(user_id, {})
    if not state.get("connected"):
        raise HTTPException(401, "GitHub not connected")

    try:
        gh = state["gh"]
        repository = gh.get_repo(f"{owner}/{repo}")
        contents = repository.get_contents(path)

        items = []
        if isinstance(contents, list):
            for item in contents:
                items.append({
                    "name": item.name,
                    "path": item.path,
                    "type": item.type,
                    "size": item.size,
                    "url": item.html_url,
                })
        else:
            items.append({
                "name": contents.name,
                "path": contents.path,
                "type": contents.type,
                "size": contents.size,
                "url": contents.html_url,
            })

        return {"items": items}
    except Exception as e:
        raise HTTPException(500, f"Failed to fetch contents: {e}")


@router.get("/repos/{owner}/{repo}/file")
async def get_repo_file(owner: str, repo: str, path: str, request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    state = svc.state.get(user_id, {})
    if not state.get("connected"):
        raise HTTPException(401, "GitHub not connected")

    try:
        gh = state["gh"]
        repository = gh.get_repo(f"{owner}/{repo}")
        file_content = repository.get_contents(path)

        if isinstance(file_content, list):
            raise HTTPException(400, "Path is a directory, not a file")

        content_bytes = file_content.decoded_content
        try:
            content = content_bytes.decode("utf-8")
            encoding = "utf-8"
        except UnicodeDecodeError:
            try:
                content = content_bytes.decode("utf-16")
                encoding = "utf-16"
            except UnicodeDecodeError:
                content = "[Binary file - Content cannot be displayed in text viewer]"
                encoding = "binary"

        return {
            "content": content,
            "encoding": encoding,
            "size": file_content.size,
            "name": file_content.name,
            "path": file_content.path,
        }
    except Exception as e:
        raise HTTPException(500, f"Failed to fetch file: {e}")


@router.post("/disconnect")
async def disconnect(request: Request):
    user_id = getattr(request.state, "user_id", "local")
    svc = request.app.state.github_service
    svc.disconnect(user_id)
    return {"disconnected": True}
