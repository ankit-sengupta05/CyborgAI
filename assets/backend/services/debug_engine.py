"""
Debug Engine for GSD Projects
Performs health checks, auto-fixes code, and validates endpoints.
"""
import os
import uuid
import structlog
from pathlib import Path
from pydantic import BaseModel
from services.llm_service import LLMService

log = structlog.get_logger(__name__)


class DebugIssue(BaseModel):
    id: str
    file: str
    line: int
    message: str
    severity: str  # error | warning | info
    status: str    # pending | fixed | failed


class DebugEngine:
    def __init__(self, workspace_dir: Path):
        self.workspace_dir = workspace_dir
        self.issues: list[DebugIssue] = []

    async def run_diagnostics(self) -> list[DebugIssue]:
        """Scan workspace for issues."""
        self.issues = []
        # 1. Static analysis (simple regex/syntax check for now)
        for root, _, files in os.walk(self.workspace_dir):
            for file in files:
                if file.endswith((".py", ".js", ".dart", ".html")):
                    path = Path(root) / file
                    await self._check_file(path)

        return self.issues

    async def _check_file(self, path: Path):
        # Placeholder for real linting/check
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            if "FIXME" in content or "TODO" in content:
                self.issues.append(DebugIssue(
                    id=str(uuid.uuid4())[:8],
                    file=str(path.relative_to(self.workspace_dir)),
                    line=0,
                    message="Found unresolved FIXME/TODO",
                    severity="warning",
                    status="pending"
                ))

    async def auto_fix(self, issue: DebugIssue, llm: LLMService):
        """Fix a specific issue using LLM."""
        issue.status = "fixing"
        file_path = self.workspace_dir / issue.file

        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        prompt = f"""You are a senior debugger. Fix the following issue in the code.
FILE: {issue.file}
ISSUE: {issue.message}

CODE:
{content}

Return ONLY the corrected code. No explanation. No markdown blocks."""

        fixed_code = await llm.complete(prompt, temperature=0.1)

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(fixed_code)

        issue.status = "fixed"
        return True
