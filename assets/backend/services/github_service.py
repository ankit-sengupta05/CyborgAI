import asyncio
import json
import os
from pathlib import Path
from typing import Optional, Dict, Any
import structlog
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from config.settings import settings

log = structlog.get_logger(__name__)

# ACE + AI OS vault directory structure (from PRD 1.0)
VAULT_DIRS = {
    "atlas":        "ACE/Atlas",
    "calendar":     "ACE/Calendar",
    "efforts":      "ACE/Efforts",
    "ai_os":        "AI_OS",
    "inbox":        "Inbox",
    "archive":      "Archive",
    "app_system":   ".ai_os",
}

VAULT_SUBDIRS = [
    "ACE/Atlas/Concepts",
    "ACE/Atlas/People",
    "ACE/Atlas/Resources",
    "ACE/Calendar/2026/05-May",
    "AI_OS/skills",
    "Inbox/images",
    "Inbox/videos",
    "Inbox/audio",
    "Inbox/documents",
    ".ai_os/graph_cache",
    ".ai_os/embeddings_cache",
    ".ai_os/ingestion_queue",
]


class VaultFileWatcher(FileSystemEventHandler):
    def __init__(self, service: 'GitHubService'):
        self.service = service
        self.loop = asyncio.get_event_loop()

    def on_modified(self, event):
        if not event.is_directory:
            log.info(f"Local vault modified: {event.src_path}")
            self.loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.service.queue_push(event.src_path))
            )

    def on_created(self, event):
        if not event.is_directory:
            log.info(f"Local vault file created: {event.src_path}")
            self.loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.service.queue_push(event.src_path))
            )

    def on_moved(self, event):
        if not event.is_directory:
            log.info(f"Local vault file moved: {event.dest_path}")
            self.loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.service.queue_push(event.dest_path))
            )


class GitHubService:
    def __init__(self):
        self.config_path = settings.data_dir / "github_config.json"
        self.state: Dict[str, Any] = {}
        self._sync_queue = asyncio.Queue()
        self._observer: Optional[Observer] = None
        self._is_running = False
        self._vault_service = None
        self._retry_queue = []  # List of (action, data, retry_count)

    async def initialize(self, vault_service=None):
        self._vault_service = vault_service
        self._load_all_configs()

        # Start background sync worker
        self._is_running = True
        asyncio.create_task(self._sync_worker())

        # Start file watcher
        self._start_watcher()

        # Periodic pull
        asyncio.create_task(self._periodic_pull())

        # Initial force sync for all configured users
        for user_id in self.state:
            if self.state[user_id].get("vault_repo"):
                asyncio.create_task(self.force_sync(user_id))

        log.info("GitHub Service initialized with initial sync task")

    def _load_all_configs(self):
        if self.config_path.exists():
            try:
                with open(self.config_path, "r") as f:
                    config = json.load(f)
                    for user_id, data in config.items():
                        if data.get("token"):
                            self._auto_connect(user_id, data)
            except Exception as e:
                log.error(f"Failed to load GitHub configs: {e}")

    def _auto_connect(self, user_id: str, data: dict):
        try:
            from github import Github
            gh = Github(data["token"])
            user = gh.get_user()
            self.state[user_id] = {
                "gh": gh,
                "connected": True,
                "username": user.login,
                "avatar_url": user.avatar_url,
                "token": data["token"],
                "vault_repo": data.get("vault_repo")
            }
            log.info(f"Auto-connected GitHub for {user.login}")
        except Exception as e:
            log.warning(f"Failed to auto-connect GitHub for {user_id}: {e}")

    def _save_config(self, user_id: str):
        try:
            settings.data_dir.mkdir(parents=True, exist_ok=True)
            config = {}
            if self.config_path.exists():
                with open(self.config_path, "r") as f:
                    config = json.load(f)

            user_state = self.state.get(user_id, {})
            config[user_id] = {
                "token": user_state.get("token"),
                "vault_repo": user_state.get("vault_repo")
            }

            with open(self.config_path, "w") as f:
                json.dump(config, f)
        except Exception as e:
            log.error(f"Failed to save GitHub config: {e}")

    async def connect(self, user_id: str, token: str):
        from github import Github
        gh = Github(token)
        user = gh.get_user()

        self.state[user_id] = {
            "connected": True,
            "token": token,
            "username": user.login,
            "avatar_url": user.avatar_url,
            "gh": gh,
            "vault_repo": self.state.get(user_id, {}).get("vault_repo"),
            "last_error": None
        }
        self._save_config(user_id)
        return self.state[user_id]

    def disconnect(self, user_id: str):
        self.state.pop(user_id, None)
        if self.config_path.exists():
            try:
                with open(self.config_path, "r") as f:
                    config = json.load(f)
                if user_id in config:
                    del config[user_id]
                    with open(self.config_path, "w") as f:
                        json.dump(config, f)
            except Exception:
                pass

    async def _initialize_vault_structure(self, user_id: str, repo_name: str):
        """Create the standard AI-OS folder structure in the GitHub repo."""
        try:
            user_state = self.state.get(user_id)
            if not user_state:
                return
            gh = user_state["gh"]
            repo = gh.get_repo(repo_name)

            # 1. Create folders (by creating a placeholder .gitignore in each)
            all_folders = list(VAULT_DIRS.values()) + VAULT_SUBDIRS
            for folder in all_folders:
                path = f"{folder}/.gitignore"
                try:
                    repo.get_contents(path)
                    # Already exists
                except Exception:
                    repo.create_file(
                        path,
                        f"init: create {folder}",
                        "",
                        branch=repo.default_branch
                    )
                    log.info(f"Created folder on GitHub: {folder}")

            # 2. Create Vault Map
            readme_path = f"{VAULT_DIRS['ai_os']}/vault_map.md"
            try:
                repo.get_contents(readme_path)
            except Exception:
                content = """---
id: vault-map
title: Vault Map
tags: [cyborg, getting-started]
type: note
status: active
---

# Welcome to your AI OS Vault

This is your personal knowledge base, synchronized with your GitHub repository using the
**ACE Structure** (Atlas, Calendar, Efforts).

## AI-OS Directory Structure

| Folder | Purpose |
|--------|---------|
| `ACE/Atlas` | Permanent knowledge (concepts, people, resources) |
| `ACE/Calendar` | Time-based notes and journals |
| `ACE/Efforts` | Active projects and tasks |
| `AI_OS` | System configuration and portable identity (`me.md`) |
| `Inbox` | Raw ingestion area for images, video, and documents |
| `Archive` | Completed or inactive content |

## Getting Started

1. Set up your identity in `AI_OS/me.md`.
2. Drop files into `Inbox/` for automatic ingestion.
3. Use the **Knowledge Graph** to explore connections.

[[Cyborg Knowledge Graph]] | [[AI OS Architecture]]
"""
                repo.create_file(
                    readme_path,
                    "init: vault map",
                    content,
                    branch=repo.default_branch
                )
                log.info("Created vault map on GitHub")

            # 3. Create Root README.md
            root_readme_path = "README.md"
            try:
                repo.get_contents(root_readme_path)
            except Exception:
                root_content = """# Cyborg AI OS Vault

This repository is your personal knowledge base, managed by the **Cyborg AI OS**.

## 🧠 ACE Structure
This vault uses the **Atlas, Calendar, Efforts (ACE)** framework for organization:

- **ACE/Atlas**: Your permanent knowledge base and references.
- **ACE/Calendar**: Time-indexed logs and daily notes.
- **ACE/Efforts**: Active projects and task tracking.
- **AI_OS**: System configuration and your **Portable Identity** (`me.md`).

## 🛠️ Usage
All changes are synchronized in real-time from your local Cyborg installation.

> [!TIP]
> Visit `AI_OS/vault_map.md` for a detailed guide on how to use this vault.
"""
                repo.create_file(
                    root_readme_path,
                    "init: root readme",
                    root_content,
                    branch=repo.default_branch
                )
                log.info("Created root README on GitHub")

        except Exception as e:
            log.error(f"Failed to initialize vault structure: {e}")

    async def set_vault_repo(self, user_id: str, repo_name: str):
        if user_id in self.state:
            self.state[user_id]["vault_repo"] = repo_name
            self._save_config(user_id)
            # 1. Initialize structure
            await self._initialize_vault_structure(user_id, repo_name)
            # 2. Pull remote changes
            await self.pull_vault(user_id)
            # 3. Push local changes (Initial sync)
            await self.force_sync(user_id)
            return True
        return False

    def _start_watcher(self):
        vault_path = settings.brain_dir
        vault_path.mkdir(parents=True, exist_ok=True)

        self._observer = Observer()
        self._observer.schedule(VaultFileWatcher(self), str(vault_path), recursive=True)
        self._observer.start()
        log.info(f"Vault watcher started on {vault_path}")

    async def queue_push(self, file_path: str):
        await self._sync_queue.put(("push", file_path))

    async def _sync_worker(self):
        log.info("Starting background sync worker")
        while self._is_running:
            try:
                # 1. Handle main queue
                while not self._sync_queue.empty():
                    action, data = await self._sync_queue.get()
                    log.debug(f"Sync worker processing: {action} {data}")
                    if action == "push":
                        success = await self._perform_push(data)
                        if not success:
                            log.warning(f"Push failed, adding to retry queue: {data}")
                            self._retry_queue.append(("push", data, 1))
                    self._sync_queue.task_done()

                # 2. Handle retries (process one per loop to avoid flooding)
                if self._retry_queue:
                    retry_item = self._retry_queue.pop(0)
                    action, data, count = retry_item
                    log.info(f"Retrying sync (attempt {count}/5): {data}")

                    success = await self._perform_push(data)
                    if not success and count < 5:
                        self._retry_queue.append((action, data, count + 1))
                    elif not success:
                        log.error(f"Sync failed after max retries: {data}")

            except Exception as e:
                log.error(f"Sync worker loop error: {e}")

            await asyncio.sleep(5)  # Throttle to save CPU and handle network gaps

    async def _perform_push(self, file_path: str) -> bool:
        """Push to all connected users. Returns True if AT LEAST ONE successful."""
        pushed_any = False
        connected_count = 0
        for user_id, user_state in self.state.items():
            if user_state.get("connected") and user_state.get("vault_repo"):
                connected_count += 1
                try:
                    await self._push_file_to_repo(user_id, file_path)
                    pushed_any = True
                except Exception as e:
                    log.warning(f"Push failed for {user_id}: {e}")

        # If no one is connected, we don't count it as a "failure" that needs retry,
        # unless we want to wait for connection.
        if connected_count == 0:
            return True  # Don't retry if no repo is even configured

        return pushed_any

    async def _push_file_to_repo(self, user_id: str, local_path: str):
        user_state = self.state[user_id]
        gh = user_state["gh"]
        repo = gh.get_repo(user_state["vault_repo"])

        vault_root = settings.brain_dir
        rel_path = str(Path(local_path).relative_to(vault_root)).replace("\\", "/")

        if not os.path.exists(local_path):
            return

        try:
            # Detect encoding and read
            content_bytes = Path(local_path).read_bytes()
            try:
                content = content_bytes.decode("utf-8")
            except UnicodeDecodeError:
                content = content_bytes.decode("utf-16")

            try:
                existing = repo.get_contents(rel_path)
                # Only update if content changed
                if existing.decoded_content.decode("utf-8", errors="ignore") != content:
                    repo.update_file(
                        rel_path,
                        f"sync: update {rel_path}",
                        content,
                        existing.sha,
                    )
                    log.info(f"Pushed update to GitHub: {rel_path}")
            except Exception:
                repo.create_file(
                    rel_path,
                    f"sync: add {rel_path}",
                    content,
                )
                log.info(f"Pushed new file to GitHub: {rel_path}")
        except Exception as e:
            err_msg = str(e)
            if "403" in err_msg:
                err_msg = (
                    "403 Forbidden: Ensure your GitHub Token has 'repo' scope "
                    "(for private repos) or 'contents:write'."
                )

            if user_id in self.state:
                self.state[user_id]["last_error"] = err_msg

            log.error(f"Push failed: {err_msg}", user=user_state.get("username"))
            raise e

    async def force_sync(self, user_id: str):
        """Force a full sync: push all local files to GitHub."""
        user_state = self.state.get(user_id)
        if not user_state or not user_state.get("vault_repo"):
            log.warning(f"Cannot force sync for {user_id}: No repo configured")
            return

        log.info(f"Forcing full vault sync to GitHub for {user_id}")
        vault_root = settings.brain_dir

        # 1. Initialize structure first
        await self._initialize_vault_structure(user_id, user_state["vault_repo"])

        # 2. Push all files recursively
        count = 0
        for item in vault_root.rglob("*"):
            if item.is_file():
                # Check for ignored files
                if ".ai_os" in str(item) and ("cache" in str(item) or "queue" in str(item)):
                    continue  # Skip heavy cache files

                await self.queue_push(str(item))
                count += 1

        log.info(f"Queued {count} files for initial vault sync")

    async def _periodic_pull(self):
        while self._is_running:
            await asyncio.sleep(300)  # Every 5 minutes
            for user_id in self.state:
                try:
                    await self.pull_vault(user_id)
                except Exception:
                    pass

    async def pull_vault(self, user_id: str):
        user_state = self.state.get(user_id)
        if not user_state or not user_state.get("vault_repo"):
            return

        log.info(f"Pulling vault changes from GitHub for {user_id}")
        try:
            gh = user_state["gh"]
            repo = gh.get_repo(user_state["vault_repo"])
            vault_root = settings.brain_dir

            # Recursive pull of all .md files
            contents = repo.get_contents("")
            while contents:
                file_content = contents.pop(0)
                if file_content.type == "dir":
                    contents.extend(repo.get_contents(file_content.path))
                elif file_content.name.endswith(".md"):
                    local_path = vault_root / file_content.path
                    local_path.parent.mkdir(parents=True, exist_ok=True)

                    remote_bytes = file_content.decoded_content
                    try:
                        remote_text = remote_bytes.decode("utf-8")
                    except UnicodeDecodeError:
                        remote_text = remote_bytes.decode("utf-16")

                    # Only write if different
                    is_diff = (
                        not local_path.exists() or
                        local_path.read_text(encoding="utf-8", errors="ignore") != remote_text
                    )
                    if is_diff:
                        local_path.write_text(remote_text, encoding="utf-8")
                        log.info(f"Pulled file from GitHub: {file_content.path}")

            if self._vault_service:
                await self._vault_service.initialize()

        except Exception as e:
            err_msg = str(e)
            if "403" in err_msg:
                err_msg = "403 Forbidden: Token lacks scopes or rate limit exceeded."

            if user_id in self.state:
                self.state[user_id]["last_error"] = err_msg

            log.error(f"Pull failed for {user_id}: {err_msg}")

    async def cleanup(self):
        self._is_running = False
        if self._observer:
            self._observer.stop()
            self._observer.join()
