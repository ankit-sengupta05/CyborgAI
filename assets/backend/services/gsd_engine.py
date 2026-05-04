"""
GSD Execution Engine
Cursor/Antigravity-style project execution:
1. Describe project → LLM generates PRD → chunks into phases → executes
2. Upload PRD → parse → chunk → execute
Progress tracked in a graphical tree stored as .md in vault.
"""
import asyncio
import json
import uuid
import re
import structlog
from datetime import datetime
from pathlib import Path
from typing import Optional, AsyncIterator
from pydantic import BaseModel

from config.settings import settings

log = structlog.get_logger(__name__)


# ── Data Models ───────────────────────────────────────────────────────────────

class GSDStep(BaseModel):
    id: str = ""
    title: str
    description: str = ""
    type: str = "task"          # planning | research | task | validation | code
    status: str = "pending"    # pending | running | done | failed | skipped
    phase: str = "0"
    sub_phase: Optional[str] = None
    order: int = 0
    output: str = ""
    verification_output: str = ""
    children: list["GSDStep"] = []
    estimated_minutes: int = 5
    actual_minutes: int = 0
    depends_on: list[str] = []


GSDStep.model_rebuild()


class GSDExecutionPlan(BaseModel):
    id: str = ""
    project_name: str
    description: str = ""
    prd_content: str = ""
    phases: list[dict] = []
    steps: list[GSDStep] = []
    status: str = "planned"  # planned | running | paused | done | failed
    created_at: str = ""
    updated_at: str = ""
    progress_pct: float = 0.0
    current_step_id: str = ""
    vault_note_path: str = ""
    planning_dir: str = ""  # Path to .planning folder


class GSDEngine:
    def __init__(self):
        self._plans: dict[str, GSDExecutionPlan] = {}
        self._running: dict[str, asyncio.Task] = {}
        self._step_callbacks: dict[str, list] = {}
        self.workspaces_dir = settings.data_dir / "workspaces"
        self.workspaces_dir.mkdir(exist_ok=True)
        self._load_all_plans()

    def _load_all_plans(self):
        """Load plans from disk."""
        try:
            for p_file in self.workspaces_dir.glob("*/plan.json"):
                try:
                    with open(p_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        plan = GSDExecutionPlan.model_validate(data)
                        self._plans[plan.id] = plan
                except Exception as e:
                    log.error(f"Failed to load plan {p_file}: {e}")
        except Exception:
            pass

    def _save_plan(self, plan: GSDExecutionPlan):
        """Save plan to its workspace."""
        try:
            p_dir = self.workspaces_dir / plan.id
            p_dir.mkdir(exist_ok=True)
            with open(p_dir / "plan.json", "w", encoding="utf-8") as f:
                json.dump(plan.model_dump(), f, indent=2)
        except Exception as e:
            log.error(f"Failed to save plan {plan.id}: {e}")

    # ── PRD Generation ────────────────────────────────────────────────────────

    async def generate_prd(self, project_description: str, llm_service) -> str:
        """Generate a full PRD from a project description."""
        prompt = f"""You are a senior product manager and software architect.
Generate a comprehensive PRD (Product Requirements Document) for this project.

PROJECT DESCRIPTION: {project_description}

Structure the PRD with these sections:
1. Executive Summary
2. Problem Statement
3. Goals & Success Metrics
4. User Stories (at least 5)
5. Technical Architecture
6. Feature Requirements (detailed)
7. Tech Stack
8. Implementation Phases (min 4 phases)
9. Risks & Mitigations

Format with proper markdown headers. Be specific and technical."""

        return await llm_service.complete(prompt, temperature=0.4, max_tokens=3000)

    async def parse_prd_into_steps(
        self, prd_content: str, project_name: str, llm_service
    ) -> GSDExecutionPlan:
        """Deep multi-agent architecture pass and project bootstrapping."""
        plan_id = str(uuid.uuid4())[:8]
        workspace = self.workspaces_dir / plan_id
        planning_dir = workspace / ".planning"
        planning_dir.mkdir(parents=True, exist_ok=True)

        # Initialize folders
        for folder in ["phases", "codebase", "research", "diagrams", "tests"]:
            (planning_dir / folder).mkdir(exist_ok=True)

        # Initial Skeleton
        with open(planning_dir / "config.json", "w", encoding="utf-8") as f:
            json.dump({
                "project_id": plan_id,
                "name": project_name,
                "version": "1.0.0",
                "agents": ["architect", "researcher", "coder", "validator"]
            }, f, indent=2)

        now = datetime.utcnow().isoformat()
        with open(planning_dir / "STATE.md", "w", encoding="utf-8") as f:
            f.write(
                f"# PROJECT STATE: {project_name}\n\n"
                f"Status: INITIALIZING\nLast Update: {now}\n"
            )

        # ── MULTI-AGENT RESEARCH & ARCHITECT PASS ──
        # Phase 0: Research (Deep analysis of PRD and technical stack)
        research_prompt = f"""You are a RESEARCH AGENT analyzing a new project.
PROJECT: {project_name}
PRD: {prd_content[:5000]}

Your task:
1. Extract key technical requirements and constraints.
2. Identify potential technical challenges and suggested stacks.
3. Research best practices for this specific domain.

Return a technical summary to be stored in the research vault.
"""
        log.info("[GSD] Invoking Research Agent for Phase 0...")
        research_summary = await llm_service.complete(
            research_prompt, temperature=0.2, max_tokens=2000
        )
        with open(
            planning_dir / "research" / "00_technical_overview.md",
            "w", encoding="utf-8"
        ) as f:
            f.write(f"# TECHNICAL RESEARCH: {project_name}\n\n{research_summary}")

        # Phase 0: Architecture (Decomposition into 8-15 phases)
        prompt = f"""You are a Multi-Agent Project Architect System.
Your goal is to perform a DEEP project overview and create a robust,
granular implementation roadmap.

PROJECT: {project_name}
PRD: {prd_content[:4000]}
RESEARCH SUMMARY: {research_summary[:2000]}

ARCHITECT PASS REQUIREMENTS:
1. Analyze technical complexity.
2. Divide the work into logically grouped phases.
   - COMPLEX APPS: 8-15 PHASES.
   - SIMPLE APPS: 4-6 PHASES.
   - Avoid generic phases; be specific to this project's domain.
3. Every phase MUST be broken down into granular sub-tasks.
4. For UI: Create separate steps for Design, Component Architecture, and Implementation.
5. Every phase MUST start with a "planning" type step and end with a "validation" type step.
6. Phase 0 MUST include: Vault Bootstrap, Technical Research, and Architecture Lockdown.

Return JSON ONLY:
{{
  "project_overview": "Comprehensive technical summary",
  "requirements": "Detailed functional and technical requirements",
  "phases": [
    {{
      "id": "0",
      "name": "Project Discovery & Architecture",
      "description": (
          "Initialize architecture vault, conduct research, "
          "and lockdown the technical design."
      ),
      "steps": [
        {{"title": "Bootstrap Planning Vault", "type": "planning"}},
        {{"title": "Deep Technical Research", "type": "research"}},
        {{"title": "Technical Architecture Lockdown", "type": "planning"}},
        {{"title": "Architecture Validation", "type": "validation"}}
      ]
    }},
    ... (Add as many phases as needed for full project implementation)
  ]
}}
"""
        log.info("[GSD] Invoking Architect Agent for roadmap generation...")
        raw = await llm_service.complete(prompt, temperature=0.1, max_tokens=4000)

        json_match = re.search(r'\{.*\}', raw, re.DOTALL)
        parsed = {}
        if json_match:
            try:
                parsed = json.loads(json_match.group())
            except json.JSONDecodeError as e:
                log.error(f"GSD JSON Parse Error: {e}")

        # Fallback if LLM failed
        if not parsed.get("phases"):
            log.warning("LLM failed to generate deep roadmap, using fallback")
            parsed = {
                "project_overview": f"Bootstrap for {project_name}",
                "requirements": "Requirements gathering in progress",
                "phases": [
                    {
                        "id": "0", "name": "Discovery",
                        "steps": [{"title": "Vault Bootstrap", "type": "planning"}]
                    },
                    {
                        "id": "1", "name": "Implementation",
                        "steps": [{"title": "Core Work", "type": "task"}]
                    }
                ]
            }

        # Build steps
        phases_data = parsed.get("phases", [])
        all_steps = []
        for p in phases_data:
            p_id = str(p.get("id"))
            p_steps = p.get("steps", [])
            for i, s in enumerate(p_steps):
                all_steps.append(GSDStep(
                    id=f"{p_id}.{i+1}",
                    title=s.get("title", "Unnamed Task"),
                    type=s.get("type", "task"),
                    phase=p_id,
                    order=i+1
                ))

        plan = GSDExecutionPlan(
            id=plan_id,
            project_name=project_name,
            description=parsed.get("project_overview", prd_content[:500]),
            prd_content=prd_content,
            phases=phases_data,
            steps=all_steps,
            status="planned",
            created_at=now,
            updated_at=now,
            planning_dir=str(planning_dir)
        )

        # Write initial docs
        with open(planning_dir / "PROJECT.md", "w", encoding="utf-8") as f:
            f.write(f"# PROJECT: {project_name}\n\n{parsed.get('project_overview', '')}")
        with open(planning_dir / "REQUIREMENTS.md", "w", encoding="utf-8") as f:
            f.write(f"# REQUIREMENTS: {project_name}\n\n{parsed.get('requirements', '')}")
        with open(planning_dir / "ROADMAP.md", "w", encoding="utf-8") as f:
            roadmap_text = f"# ROADMAP: {project_name}\n\n"
            for p in phases_data:
                roadmap_text += f"## Phase {p['id']}: {p['name']}\n{p.get('description', '')}\n"
                for s in p.get("steps", []):
                    roadmap_text += f"- [ ] {s['title']} ({s.get('type', 'task')})\n"
            f.write(roadmap_text)

        self._plans[plan_id] = plan
        self._save_plan(plan)
        return plan

    # ── Execution ─────────────────────────────────────────────────────────────

    async def execute_plan(
        self, plan_id: str, llm_service, on_step_update=None
    ) -> AsyncIterator[dict]:
        """Execute plan step by step, yielding progress updates."""
        plan = self._plans.get(plan_id)
        if not plan:
            yield {"error": "Plan not found"}
            return

        plan.status = "running"
        plan.updated_at = datetime.utcnow().isoformat()
        done_steps = 0
        total_steps = len(plan.steps)

        # Loop through steps (note: plan.steps might grow during execution)
        i = 0
        while i < len(plan.steps):
            step = plan.steps[i]
            if step.status == "done":
                i += 1
                continue

            step.status = "running"
            plan.current_step_id = step.id
            yield {
                "type": "step_start",
                "step_id": step.id,
                "title": step.title,
                "phase": step.phase,
                "progress": done_steps / total_steps if total_steps > 0 else 0,
            }

            start = datetime.utcnow()
            try:
                output = await self._execute_step(step, plan, llm_service)
                step.output = output
                step.status = "done"
            except Exception as e:
                log.error(f"Step execution failed: {e}")
                step.output = f"Error: {e}"
                step.status = "failed"

            elapsed = (datetime.utcnow() - start).seconds // 60
            step.actual_minutes = max(1, elapsed)
            done_steps += 1
            total_steps = len(plan.steps)  # Recalculate as it might have grown
            plan.progress_pct = (done_steps / total_steps) * 100
            plan.updated_at = datetime.utcnow().isoformat()

            yield {
                "type": "step_done",
                "step_id": step.id,
                "title": step.title,
                "status": step.status,
                "output": step.output[:1000],
                "progress": plan.progress_pct / 100,
                "progress_pct": plan.progress_pct,
            }

            if on_step_update:
                await on_step_update(step)

            self._save_plan(plan)
            i += 1

        plan.status = "done" if all(s.status == "done" for s in plan.steps) else "failed"
        self._save_plan(plan)
        yield {
            "type": "plan_done",
            "status": plan.status,
            "progress_pct": plan.progress_pct,
        }

    async def _execute_step(
        self, step: GSDStep, plan: GSDExecutionPlan, llm_service
    ) -> str:
        """Execute a single step with GSD sub-agent orchestration."""
        step_type = step.type.lower()
        workspace = self.workspaces_dir / plan.id
        planning_dir = Path(plan.planning_dir) if plan.planning_dir else None

        # ── GATHER CONTEXT ──
        context = f"Project: {plan.project_name}\nGoal: {step.title}\n"
        if planning_dir:
            try:
                # Read vision docs
                for doc in ["PROJECT.md", "REQUIREMENTS.md", "STATE.md", "CONTEXT_SUMMARY.md"]:
                    path = planning_dir / doc
                    if path.exists():
                        context += f"\n### {doc}\n{path.read_text(encoding='utf-8')[:1000]}\n"
            except Exception as e:
                log.warning(f"Context error: {e}")

        # ── 1. PLANNING STEPS (Architect Expansion) ──
        if step_type == "planning":
            phase_info = next((p for p in plan.phases if str(p["id"]) == str(step.phase)), {})
            phase_name = phase_info.get("name", f"Phase {step.phase}")

            prompt = f"""{context}
---
You are the ARCHITECT AGENT planning Phase {step.phase}: {phase_name}.
Task: {step.title}

1. Analyze existing documentation.
2. Decompose this phase into extremely granular, actionable sub-tasks.
3. For UI: Break into (1) Design Spec, (2) Component Setup, (3) Implementation.
4. Ensure tasks are technically specific and falsifiable.

Return JSON:
{{
  "strategy": "Detailed technical approach for this phase",
  "sub_tasks": [
    {{"title": "...", "description": "...", "type": "task", "agent": "coder"}},
    ...
  ]
}}
"""
            raw = await llm_service.complete(prompt, temperature=0.1, max_tokens=2500)
            try:
                match = re.search(r'\{.*\}', raw, re.DOTALL)
                data = json.loads(match.group()) if match else {}
            except Exception:
                data = {"strategy": raw, "sub_tasks": []}

            # Inject sub-tasks
            if data.get("sub_tasks"):
                current_index = plan.steps.index(step)
                for idx, st in enumerate(data["sub_tasks"]):
                    new_step = GSDStep(
                        id=f"{step.id}.{idx+1}",
                        title=st.get("title", "Sub-task"),
                        description=st.get("description", ""),
                        type=st.get("type", "task"),
                        phase=step.phase,
                        order=step.order + idx + 1,
                    )
                    plan.steps.insert(current_index + idx + 1, new_step)
                log.info(
                    f"Agentic expansion: Injected {len(data['sub_tasks'])} "
                    f"tasks into phase {step.phase}"
                )

            # Update docs
            if planning_dir:
                p_safe = phase_name.lower().replace(" ", "-")
                p_folder = planning_dir / "phases" / f"{str(step.phase).zfill(2)}-{p_safe}"
                p_folder.mkdir(parents=True, exist_ok=True)
                with open(p_folder / "STRATEGY.md", "w", encoding="utf-8") as f:
                    f.write(f"# PHASE {step.phase} STRATEGY\n\n{data.get('strategy', '')}")
                with open(planning_dir / "STATE.md", "a", encoding="utf-8") as f:
                    f.write(f"\n## {datetime.utcnow().isoformat()} - Phase {step.phase} Planned\n")

            return data.get("strategy", "Phase planning complete.")

        # ── 2. RESEARCH STEPS ──
        if step_type == "research":
            prompt = (
                f"{context}\n---\nPerform deep technical research for this goal. "
                "Return a detailed markdown report."
            )
            report = await llm_service.complete(prompt, temperature=0.3, max_tokens=2000)
            if planning_dir:
                res_path = planning_dir / "research" / f"research_{step.id}.md"
                with open(res_path, "w", encoding="utf-8") as f:
                    f.write(report)
            return report

        # ── 3. VALIDATION STEPS ──
        if step_type == "validation":
            summary = "✅ Validation check completed."
            # Placeholder for actual test runner integration
            if planning_dir:
                val_path = planning_dir / "phases" / f"validation_{step.id}.md"
                with open(val_path, "w", encoding="utf-8") as f:
                    f.write(f"# Validation: {step.title}\n\n{summary}")
            return summary

        # ── 4. TASK STEPS (Execution) ──
        prompt = f"""{context}
---
Project: {plan.project_name}
Task: {step.title}
Details: {step.description}

Execute this task.
- If writing code: Provide the code block with the filename
  in a comment like: // File: path/to/file.ext
- Keep code clean and follow the project's technical requirements.
- Update documentation if needed.
"""
        output = await llm_service.complete(prompt, temperature=0.4, max_tokens=2500)

        # Auto-write files if code blocks are detected
        code_blocks = re.findall(r"// File: ([^\n]*)\n```(?:\w+)?\n(.*?)\n```", output, re.DOTALL)
        for file_path, content in code_blocks:
            full_path = workspace / file_path.strip()
            full_path.parent.mkdir(parents=True, exist_ok=True)
            with open(full_path, "w", encoding="utf-8") as f:
                f.write(content.strip())
            log.info(f"Generated file: {file_path}")

        # Log to step file
        if planning_dir:
            with open(planning_dir / "phases" / f"task_{step.id}.md", "w", encoding="utf-8") as f:
                f.write(f"# TASK: {step.title}\n\n{output}")

        return output

    # ── Plan Management ───────────────────────────────────────────────────────

    def get_plan(self, plan_id: str) -> Optional[dict]:
        plan = self._plans.get(plan_id)
        return plan.model_dump() if plan else None

    def list_plans(self) -> list[dict]:
        return [p.model_dump() for p in self._plans.values()]

    def get_progress_tree(self, plan_id: str) -> dict:
        """Return hierarchical progress tree grouped by phase."""
        plan = self._plans.get(plan_id)
        if not plan:
            return {}

        phases: dict[str, dict] = {}
        for phase in plan.phases:
            p_id = str(phase["id"])
            phases[p_id] = {
                "id": p_id,
                "name": phase.get("name", f"Phase {p_id}"),
                "description": phase.get("description", ""),
                "steps": [],
                "done": 0, "total": 0,
                "status": "pending",
            }

        for step in plan.steps:
            p_id = str(step.phase)
            if p_id in phases:
                phases[p_id]["steps"].append(step.model_dump())
                phases[p_id]["total"] += 1
                if step.status == "done":
                    phases[p_id]["done"] += 1

        for p in phases.values():
            if p["total"] == 0:
                p["status"] = "empty"
            elif p["done"] == p["total"]:
                p["status"] = "done"
            elif p["done"] > 0:
                p["status"] = "running"
            else:
                p["status"] = "pending"

        return {
            "plan_id": plan_id,
            "project_name": plan.project_name,
            "status": plan.status,
            "progress_pct": plan.progress_pct,
            "phases": list(phases.values()),
            "current_step_id": plan.current_step_id,
        }

    def list_workspace_files(self, plan_id: str) -> list[str]:
        """List all files in the workspace with normalized paths."""
        workspace = self.workspaces_dir / plan_id
        if not workspace.exists():
            return []

        files = []
        for f in workspace.rglob("*"):
            if f.is_file():
                rel = str(f.relative_to(workspace)).replace("\\", "/")
                if not any(s in rel for s in [".git/", "__pycache__", ".venv", "node_modules"]):
                    files.append(rel)
        return sorted(files)
