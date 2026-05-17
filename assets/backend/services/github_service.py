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
        if not event.is_directory and ".git" not in event.src_path:
            log.debug(f"Local vault modified: {event.src_path}")
            self.loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.service.queue_push(event.src_path))
            )

    def on_created(self, event):
        if not event.is_directory and ".git" not in event.src_path:
            log.debug(f"Local vault file created: {event.src_path}")
            self.loop.call_soon_threadsafe(
                lambda: asyncio.create_task(self.service.queue_push(event.src_path))
            )

    def on_moved(self, event):
        if not event.is_directory and ".git" not in event.dest_path:
            log.debug(f"Local vault file moved: {event.dest_path}")
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
        self._self_heal_git()
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

        log.info("GitHub Service initialized with self-healing complete")

    def _self_heal_git(self):
        """Remove stale git locks and rebase states that block sync."""
        vault_git = settings.brain_dir / ".git"
        if not vault_git.exists():
            return

        log.info("Running Git Self-Healing...")
        # 1. Remove lock files
        locks = [
            vault_git / "config.lock",
            vault_git / "index.lock",
            vault_git / "FETCH_HEAD.lock",
            vault_git / "HEAD.lock",
            vault_git / "refs" / "heads" / "main.lock",
            vault_git / "refs" / "heads" / "master.lock",
            vault_git / "refs" / "remotes" / "origin" / "main.lock",
        ]
        for lock in locks:
            if lock.exists():
                try:
                    lock.unlink()
                    log.info(f"Removed stale git lock: {lock.name}")
                except Exception:
                    pass

        # 2. Cleanup rebase/merge states
        rebase_dirs = [
            vault_git / "rebase-merge",
            vault_git / "rebase-apply",
            vault_git / "MERGE_HEAD",
            vault_git / "MERGE_MSG",
            vault_git / "MERGE_MODE",
        ]
        for rd in rebase_dirs:
            if rd.exists():
                try:
                    import shutil
                    if rd.is_dir():
                        shutil.rmtree(rd)
                    else:
                        rd.unlink()
                    log.info(f"Cleaned up interrupted git state: {rd.name}")
                except Exception:
                    pass

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

    async def _run_git_command(self, args: list[str], cwd: Path) -> str:
        """Run a git command and return output."""
        try:
            process = await asyncio.create_subprocess_exec(
                "git", *args,
                cwd=str(cwd),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            if process.returncode != 0:
                err = stderr.decode().strip()
                log.error(f"Git command failed: git {' '.join(args)}", error=err)
                return f"ERROR: {err}"
            return stdout.decode().strip()
        except Exception as e:
            log.error(f"Failed to execute git: {e}")
            return f"ERROR: {e}"

    async def _git_sync_bulk(self, user_id: str) -> bool:
        """Perform a high-performance bulk git sync (add, commit, push)."""
        user_state = self.state.get(user_id)
        if not user_state or not user_state.get("vault_repo"):
            return False

        vault_root = settings.brain_dir
        repo_name = user_state["vault_repo"]
        token = user_state["token"]

        log.info(f"Starting bulk git sync for {repo_name}")

        try:
            # 1. Initialize if not a repo
            if not (vault_root / ".git").exists():
                await self._run_git_command(["init"], vault_root)
                await self._run_git_command(["checkout", "-b", "main"], vault_root)

            # 2. Configure remote with token
            remote_url = f"https://{token}@github.com/{repo_name}.git"
            await self._run_git_command(["remote", "remove", "origin"], vault_root)
            await self._run_git_command(["remote", "add", "origin", remote_url], vault_root)

            # 3. Check for changes
            status = await self._run_git_command(["status", "--porcelain"], vault_root)
            if not status and "ERROR" not in status:
                log.info("Vault is up to date, skipping push")
                return True

            # 4. Sync: Pull with rebase, then Add, Commit, Push
            await self._run_git_command(["stash"], vault_root)
            await self._run_git_command(["pull", "origin", "main", "--rebase", "-Xours"], vault_root)
            await self._run_git_command(["stash", "pop"], vault_root)
            await self._run_git_command(["add", "."], vault_root)
            await self._run_git_command(["commit", "-m", "sync: bulk update from Cyborg AI OS"], vault_root)
            
            # Use --force or handle rebase? For a simple vault, push -u origin main is safest
            # We try to push normally first
            result = await self._run_git_command(["push", "-u", "origin", "main"], vault_root)
            
            if "ERROR" in result:
                # If main fails, try master or force push if it's a dedicated vault
                await self._run_git_command(["push", "-u", "origin", "master"], vault_root)
            
            log.info(f"Bulk sync complete for {repo_name}")
            return True

        except Exception as e:
            log.error(f"Bulk sync failed: {e}")
            return False

    async def _sync_worker(self):
        log.info("Starting background sync worker")
        while self._is_running:
            try:
                # If there are items in queue, we do a bulk sync instead of file-by-file
                has_changes = False
                while not self._sync_queue.empty():
                    await self._sync_queue.get()
                    has_changes = True
                    self._sync_queue.task_done()

                if has_changes:
                    for user_id in self.state:
                        await self._git_sync_bulk(user_id)

                # Periodic retries of bulk sync if state is messy
                if self._retry_queue:
                    self._retry_queue.clear() # Bulk sync handles everything
                    for user_id in self.state:
                        await self._git_sync_bulk(user_id)

            except Exception as e:
                log.error(f"Sync worker loop error: {e}")

            await asyncio.sleep(10)  # Batch changes every 10 seconds

    async def force_sync(self, user_id: str):
        """Force a full sync using high-performance git commands."""
        log.info(f"Forcing full vault sync for {user_id}")
        success = await self._git_sync_bulk(user_id)
        if success:
            log.info(f"Force sync complete for {user_id}")
        else:
            log.error(f"Force sync failed for {user_id}")

    async def _periodic_pull(self):
        while self._is_running:
            await asyncio.sleep(300)  # Every 5 minutes
            for user_id in self.state:
                try:
                    await self.pull_vault(user_id)
                except Exception:
                    pass

    async def pull_vault(self, user_id: str):
        """Pull changes from GitHub using high-performance git commands."""
        user_state = self.state.get(user_id)
        if not user_state or not user_state.get("vault_repo"):
            return

        log.info(f"Pulling vault changes for {user_id}")
        vault_root = settings.brain_dir
        
        try:
            # 1. Ensure remote is configured
            token = user_state["token"]
            repo_name = user_state["vault_repo"]
            remote_url = f"https://{token}@github.com/{repo_name}.git"
            
            if not (vault_root / ".git").exists():
                await self._run_git_command(["init"], vault_root)
                await self._run_git_command(["remote", "add", "origin", remote_url], vault_root)

            # 2. Pull with rebase to avoid merge commits in the knowledge base
            # We use -Xours to prefer local changes if there's a conflict during auto-sync
            await self._run_git_command(["stash"], vault_root)
            result = await self._run_git_command(["pull", "origin", "main", "--rebase", "-Xours"], vault_root)
            await self._run_git_command(["stash", "pop"], vault_root)
            
            if "ERROR" in result:
                # Try master if main fails
                await self._run_git_command(["pull", "origin", "master", "--rebase", "-Xours"], vault_root)

            log.info(f"Pull complete for {user_id}")
            
            if self._vault_service:
                # Lighter reload: only parse files, don't rebuild all indices
                await self._vault_service.reload_cache()

        except Exception as e:
            log.error(f"Pull failed for {user_id}: {e}")
            if user_id in self.state:
                self.state[user_id]["last_error"] = str(e)

    async def cleanup(self):
        self._is_running = False
        if self._observer:
            self._observer.stop()
            self._observer.join()
