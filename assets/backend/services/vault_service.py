"""
Vault Service — Obsidian-compatible .md file system.
Every note has YAML frontmatter with structured metadata, tags, and [[wiki-links]].
Files live under data/vault/ organized by AI-OS directory structure.
"""
import asyncio
import re
import uuid
import structlog
from pathlib import Path
from datetime import datetime
from typing import Optional
import yaml

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

# Detailed subfolders for initialization
VAULT_SUBDIRS = [
    ".ai_os/graph_cache",
    ".ai_os/embeddings_cache",
    ".ai_os/ingestion_queue",
    "ACE/Atlas/Concepts",
    "ACE/Atlas/People",
    "ACE/Atlas/Resources",
    "ACE/Calendar/2026/04-April",
    "ACE/Efforts/Project_Alpha",
    "AI_OS/skills",
    "Inbox/images",
    "Inbox/videos",
    "Inbox/audio",
    "Inbox/documents",
    "Archive",
]

TEMPLATE_FRONTMATTER = {
    "id":          "",
    "title":       "",
    "tags":        [],
    "created":     "",
    "modified":    "",
    "type":        "note",
    "status":      "active",
    "links":       [],
    "backlinks":   [],
    "aliases":     [],
    "source":      "",
    "project":     "",
    "area":        "",
    "summary":     "",
}


class VaultNote:
    def __init__(self, path: Path, frontmatter: dict, content: str):
        self.path = path
        self.frontmatter = frontmatter
        self.content = content
        self.id = frontmatter.get("id", str(path.stem))
        self.title = frontmatter.get("title", path.stem)
        self.tags = frontmatter.get("tags", [])
        self.links = self._extract_wikilinks(content)
        self.folder = path.parent.name
        self.relative = str(path.relative_to(settings.brain_dir))

    def _extract_wikilinks(self, content: str) -> list[str]:
        """Extract [[wiki-links]] from content."""
        return re.findall(r'\[\[([^\]|]+)(?:\|[^\]]*)?\]\]', content)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "path": self.relative,
            "folder": self.folder,
            "tags": self.tags,
            "links": self.links,
            "frontmatter": self.frontmatter,
            "content": self.content,
            "summary": self.frontmatter.get("summary", ""),
            "created": self.frontmatter.get("created", ""),
            "modified": self.frontmatter.get("modified", ""),
            "type": self.frontmatter.get("type", "note"),
            "status": self.frontmatter.get("status", "active"),
            "word_count": len(self.content.split()),
        }

    def to_graph_node(self) -> dict:
        return {
            "id": self.id,
            "label": self.title,
            "path": self.relative,
            "tags": self.tags,
            "links": self.links,
            "folder": self.folder,
            "type": self.frontmatter.get("type", "note"),
            "word_count": len(self.content.split()),
        }


class VaultService:
    def __init__(self):
        self.vault_root = settings.brain_dir
        self._notes_cache: dict[str, VaultNote] = {}
        self._initialized = False

    async def initialize(self):
        """Create vault directory structure and load all notes."""
        self.vault_root.mkdir(parents=True, exist_ok=True)
        # Create top-level
        for folder in VAULT_DIRS.values():
            (self.vault_root / folder).mkdir(parents=True, exist_ok=True)
        # Create subfolders
        for sub in VAULT_SUBDIRS:
            (self.vault_root / sub).mkdir(parents=True, exist_ok=True)

        # Ensure all folders have an empty .gitignore to preserve structure on GitHub
        for folder in self.vault_root.rglob("*"):
            if folder.is_dir():
                ignore_file = folder / ".gitignore"
                if not ignore_file.exists():
                    ignore_file.touch()

        # System Files
        ignore_file = self.vault_root / "_graphify_ignore"
        if not ignore_file.exists():
            ignore_file.write_text(".ai_os/\nnode_modules/\n.git/\n", encoding="utf-8")

        config_file = self.vault_root / ".ai_os" / "config.json"
        if not config_file.exists():
            import json
            config_file.write_text(json.dumps({
                "user_settings": {},
                "llm_path": "",
                "trocr_model_path": "",
                "app_version": settings.app_version
            }, indent=4), encoding="utf-8")

        # Create starter notes
        await self._create_starter_notes()
        await self._load_all_notes()
        self._initialized = True
        log.info("Vault initialized", notes=len(self._notes_cache), root=str(self.vault_root))

    async def _create_starter_notes(self):
        """Create README and welcome note if vault is empty."""
        readme = self.vault_root / "AI_OS" / "vault_map.md"
        if not readme.exists():
            readme.write_text(self._make_note(
                title="Vault Map",
                note_type="note",
                tags=["cyborg", "getting-started"],
                content="""# Welcome to Cyborg Vault
This is your personal knowledge base, integrated with your local AI OS.

## Directory Structure

| Folder | Purpose |
|--------|---------|
| `ACE/Atlas` | Permanent knowledge (concepts, references, people) |
| `ACE/Calendar` | Time-based notes (daily logs, journals) |
| `ACE/Efforts` | Active projects and goal-oriented tasks |
| `AI_OS` | System configuration, skills, and portable identity |
| `Inbox` | Raw ingestion staging area for multimodal content |
| `Archive` | Deprecated or completed historical content |

## Frameworks

- **ACE Synthesis**: The core method for organizing information.
- **Portable Identity**: Managed via `AI_OS/me.md`.
- **In-Place Ingestion**: Raw files in `Inbox` are processed into `.md` notes.

[[Cyborg Knowledge Graph]] | [[AI_OS/_index]]
""",
            ), encoding="utf-8")

        # Root README.md
        readme_root = self.vault_root / "README.md"
        if not readme_root.exists():
            readme_root.write_text(f"""# 🧠 The Cyborg AGI Vault
Managed by **Cyborg AI OS v{settings.app_version}**

## 📂 Vault Structure
This vault uses the **ACE Synthesis Framework** combined with the **AI OS** maps layer:

- **ACE/Atlas**: Permanent knowledge (concepts, people, resources).
- **ACE/Calendar**: Time-based logs and journals.
- **ACE/Efforts**: Active projects and tasks.
- **AI_OS**: System config, skills, and **Portable Identity**.
- **Inbox**: Raw multimodal ingestion staging area.

## 🛠️ Usage
All notes are in standard Markdown with YAML frontmatter.
Real-time synchronization with GitHub is active.

---
*Generated by Cyborg AGI OS - Your local-first neural extension.*
""", encoding="utf-8")

        # ACE Indices
        indices = [
            ("ACE/Atlas/_index.md", "Atlas Index",
             "Map of your permanent knowledge."),
            ("ACE/Calendar/_index.md", "Calendar Index",
             "Map of your time-based notes."),
            ("ACE/Calendar/2026/_index.md", "2026 Index",
             "Notes for the year 2026."),
            ("ACE/Calendar/2026/04-April/_index.md", "April 2026 Index",
             "Notes for April 2026."),
            ("ACE/Efforts/_index.md", "Efforts Index",
             "Map of your active projects."),
            ("AI_OS/_index.md", "AI OS Index",
             "The operating layer of your vault."),
            ("AI_OS/skills/_index.md", "Skills Index",
             "AI-powered process documentation."),
            ("Archive/_index.md", "Archive Index",
             "History of your mind."),
        ]
        for path, title, desc in indices:
            idx_file = self.vault_root / path
            if not idx_file.exists():
                idx_file.write_text(
                    self._make_note(title, "map", ["index"], desc),
                    encoding="utf-8"
                )

        # Specific PRD Files
        prd_files = [
            ("ACE/Calendar/2026/04-April/2026-04-29.md",
             "Daily Log - 2026-04-29", "Daily capture for April 29th."),
            ("ACE/Efforts/Project_Alpha/brief.md",
             "Project Alpha Brief", "Brief for Project Alpha."),
            ("ACE/Efforts/Project_Alpha/tasks.md",
             "Project Alpha Tasks", "Tasks for Project Alpha."),
            ("ACE/Efforts/Project_Alpha/_index.md",
             "Project Alpha Index", "Index for Project Alpha."),
            ("AI_OS/skills/daily_briefing.md",
             "Daily Briefing", "Process for daily briefings."),
            ("AI_OS/skills/email_drafting.md",
             "Email Drafting", "Process for email drafting."),
        ]
        for path, title, desc in prd_files:
            p_file = self.vault_root / path
            if not p_file.exists():
                p_file.write_text(
                    self._make_note(title, "note", ["prd-starter"], desc),
                    encoding="utf-8"
                )

        # Inbox process queue (as a file)
        queue_file = self.vault_root / "Inbox" / "_process_queue.md"
        if not queue_file.exists():
            queue_file.write_text(
                "# Process Queue\nList of files pending ingestion.\n",
                encoding="utf-8"
            )

        # me.md
        me_note = self.vault_root / "AI_OS" / "me.md"
        if not me_note.exists():
            me_note.write_text(self._make_note(
                title="Portable Identity",
                note_type="identity",
                tags=["cyborg", "identity"],
                content="""# 🤖 My Digital Identity

## 👤 Who Am I?
- **Name**: Ankit Sengupta
- **Archetype**: AI Architect & Systems Developer
- **Environment**: Windows 11 | RTX 5060 | Cyborg AGI OS
- **Focus**: Building autonomous, local-first intelligence systems that bridge the
  gap between human intent and machine execution.

## 🎯 My General Goals
- [ ] **Autonomous Mastery**: Refine the Cyborg GSD engine to handle
  complex-adaptive project management.
- [ ] **Data Sovereignty**: Maintain a zero-cloud, high-performance knowledge
  vault that remains private and portable.
- [ ] **Neural Integration**: Seamlessly blend voice, vision, and text-based AI
  into a unified "Second Brain" experience.
- [ ] **Cognitive Augmentation**: Use local LLMs to eliminate repetitive
  digital tasks and amplify creative problem-solving.

## ⚒️ What Do I Do?
- **Knowledge Synthesis**: I convert fragmented information into structured,
  linked ontologies using the **ACE Framework** (Atlas, Calendar, Efforts).
- **Agentic Workflow Design**: I develop and debug hierarchical planning
  systems that decompose high-level ideas into executable technical phases.
- **Hardware Optimization**: I specialize in tuning local inference (CUDA/VRAM)
  for maximum efficiency on consumer-grade hardware.

## 🧠 Thinking Style
- [x] Non-linear / Associative
- [x] High-level / Conceptual
- [x] Detail-oriented / Technical

## ⚙️ Interaction Preferences
- **Tone**: Concise, Direct, Academic, Creative
- **Inference**: Use GPU acceleration where possible,
  prefer Q4_K_M quantization
- **AI Guidelines**: Always verify facts, prioritize local files over web search,
  keep summaries actionable.

[[Vault Map]] | [[ACE/Efforts/_index]]
""",
            ), encoding="utf-8")

        # Root README.md
        readme = self.vault_root / "README.md"
        if not readme.exists():
            readme.write_text(self._make_note(
                title="Cyborg AI OS Vault",
                note_type="guide",
                tags=["cyborg", "guide"],
                content="""# Welcome to your AI OS Vault

This is your personal knowledge base, managed by the **Cyborg AI OS**.
Everything here is local-first, multimodal, and privacy-preserving.

## 🧠 ACE Structure
Your knowledge is organized using the **Atlas, Calendar, Efforts (ACE)** framework:

- **[[ACE/Atlas/Concepts]]**: Your permanent knowledge base.
- **[[ACE/Calendar/2026/]]**: Time-indexed logs and journals.
- **[[ACE/Efforts/]]**: Active projects and task tracking.
- **[[AI_OS/me]]**: Your **Portable Identity** and preferences.

## 🛠️ Getting Started
1. Click on **[[AI_OS/me|me.md]]** to define your identity and goals.
2. Drop files into the `Inbox/` folder for automatic AI processing.
3. Use the **Knowledge Graph** to visualize connections.

---
[[AI_OS/vault_map|Vault Map]] | [[AI OS Architecture]]
""",
            ), encoding="utf-8")

    def _make_note(self, title: str, note_type: str = "note",
                   tags: list = None, content: str = "",
                   project: str = "", area: str = "") -> str:
        """Generate a full .md file with YAML frontmatter."""
        now = datetime.utcnow().isoformat()
        note_id = str(uuid.uuid4())[:8]
        fm = {
            "id": note_id,
            "title": title,
            "tags": tags or [],
            "created": now,
            "modified": now,
            "type": note_type,
            "status": "active",
            "links": [],
            "backlinks": [],
            "aliases": [],
            "source": "",
            "project": project,
            "area": area,
            "summary": "",
        }
        return f"---\n{yaml.dump(fm, default_flow_style=False, allow_unicode=True)}---\n\n{content}"

    async def _load_all_notes(self):
        """Load all .md files from vault into cache."""
        self._notes_cache = {}
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._load_sync)

    def _load_sync(self):
        for md_file in self.vault_root.rglob("*.md"):
            try:
                note = self._parse_note(md_file)
                if note:
                    self._notes_cache[note.id] = note
            except Exception as e:
                log.warning(f"Failed to parse {md_file}: {e}")

    def _parse_note(self, path: Path) -> Optional[VaultNote]:
        """Parse a .md file into a VaultNote."""
        raw = path.read_text(encoding="utf-8", errors="ignore")
        frontmatter = {}
        content = raw

        if raw.startswith("---"):
            try:
                end = raw.index("---", 3)
                fm_str = raw[3:end].strip()
                frontmatter = yaml.safe_load(fm_str) or {}
                content = raw[end + 3:].strip()
            except Exception:
                pass

        if not frontmatter.get("id"):
            frontmatter["id"] = path.stem[:16].replace(" ", "-").lower()
        if not frontmatter.get("title"):
            frontmatter["title"] = path.stem

        return VaultNote(path, frontmatter, content)

    async def list_notes(self, folder: str = None, tag: str = None) -> list[dict]:
        """List all notes, optionally filtered."""
        notes = list(self._notes_cache.values())
        if folder:
            folder_path = VAULT_DIRS.get(folder, folder)
            notes = [n for n in notes if folder_path in str(n.path)]
        if tag:
            notes = [n for n in notes if tag in n.tags]
        return [n.to_dict() for n in notes]

    async def get_note(self, note_id: str) -> Optional[dict]:
        note = self._notes_cache.get(note_id)
        if not note:
            # Try by title
            for n in self._notes_cache.values():
                if n.title == note_id or n.relative == note_id:
                    note = n
                    break
        return note.to_dict() if note else None

    async def create_note(self, title: str, content: str = "",
                          folder: str = "inbox", tags: list = None,
                          note_type: str = "note", project: str = "",
                          area: str = "") -> dict:
        folder_name = VAULT_DIRS.get(folder, "04-Inbox")
        safe_title = re.sub(r'[<>:"/\\|?*]', '-', title)
        path = self.vault_root / folder_name / f"{safe_title}.md"

        raw = self._make_note(title=title, note_type=note_type,
                              tags=tags or [], content=content,
                              project=project, area=area)
        path.write_text(raw, encoding="utf-8")

        note = self._parse_note(path)
        self._notes_cache[note.id] = note
        return note.to_dict()

    async def update_note(self, note_id: str, title: str = None,
                          content: str = None, tags: list = None,
                          frontmatter_update: dict = None) -> Optional[dict]:
        note = self._notes_cache.get(note_id)
        if not note:
            return None

        fm = dict(note.frontmatter)
        if title:
            fm["title"] = title
        if tags is not None:
            fm["tags"] = tags
        if frontmatter_update:
            fm.update(frontmatter_update)
        fm["modified"] = datetime.utcnow().isoformat()

        new_content = content if content is not None else note.content
        raw = (
            f"---\n{yaml.dump(fm, default_flow_style=False, allow_unicode=True)}"
            f"---\n\n{new_content}"
        )

        note.path.write_text(raw, encoding="utf-8")
        updated = self._parse_note(note.path)
        self._notes_cache[note_id] = updated
        return updated.to_dict()

    async def delete_note(self, note_id: str) -> bool:
        note = self._notes_cache.get(note_id)
        if not note:
            return False
        note.path.unlink(missing_ok=True)
        del self._notes_cache[note_id]
        return True

    async def search_notes(self, query: str) -> list[dict]:
        """Full-text search across all notes."""
        query_lower = query.lower()
        results = []
        for note in self._notes_cache.values():
            score = 0
            if query_lower in note.title.lower():
                score += 10
            if query_lower in note.content.lower():
                score += note.content.lower().count(query_lower)
            if any(query_lower in t.lower() for t in note.tags):
                score += 5
            if score > 0:
                d = note.to_dict()
                d["score"] = score
                # Extract snippet
                idx = note.content.lower().find(query_lower)
                if idx >= 0:
                    start = max(0, idx - 80)
                    end = min(len(note.content), idx + 160)
                    d["snippet"] = "..." + note.content[start:end] + "..."
                results.append(d)
        return sorted(results, key=lambda x: x["score"], reverse=True)[:30]

    async def get_graph_data(self) -> dict:
        """Return nodes + edges for Obsidian-style graph with clustering."""
        nodes = []
        edges = []
        title_to_id: dict[str, str] = {
            n.title: n.id for n in self._notes_cache.values()
        }

        import networkx as nx
        G = nx.Graph()

        for note in self._notes_cache.values():
            G.add_node(note.id)
            for link in note.links:
                target_id = title_to_id.get(link)
                if target_id:
                    G.add_edge(note.id, target_id)
                    edges.append({
                        "source": note.id,
                        "target": target_id,
                        "type": "wikilink",
                        "weight": 1.0,
                    })

        communities = {}
        try:
            import community as community_louvain
            communities = community_louvain.best_partition(G)
        except ImportError:
            for i, component in enumerate(nx.connected_components(G)):
                for node in component:
                    communities[node] = i

        degrees = dict(G.degree())

        for note in self._notes_cache.values():
            node_data = note.to_graph_node()
            node_data["community"] = communities.get(note.id, 0)
            node_data["degree"] = degrees.get(note.id, 0)
            nodes.append(node_data)

        # Generate community meta
        community_meta = []
        c_counts = {}
        for c in communities.values():
            c_counts[c] = c_counts.get(c, 0) + 1

        for c_id, count in c_counts.items():
            community_meta.append({
                "id": c_id,
                "nodeCount": count,
                "name": f"Cluster {c_id}",
                "summary": "Vault cluster"
            })

        return {"nodes": nodes, "edges": edges, "communities": community_meta}

    async def move_note(self, note_id: str, target_folder: str) -> Optional[dict]:
        note = self._notes_cache.get(note_id)
        if not note:
            return None
        folder_name = VAULT_DIRS.get(target_folder, target_folder)
        new_path = self.vault_root / folder_name / note.path.name
        note.path.rename(new_path)
        updated = self._parse_note(new_path)
        self._notes_cache[note_id] = updated
        return updated.to_dict()
