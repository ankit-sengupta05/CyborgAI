"""
Skills Service — Dynamic skill discovery, execution, and creation.

The Skills system follows the AI OS philosophy from the PRD:
- Skills are stored as Python modules in the vault's AI_OS/skills/ directory
- Each skill has metadata (name, description, usage, parameters)
- Skills can be auto-created by the LLM when a capability is missing
- Created skills go through a test-debug-fix loop before activation
"""
import asyncio
import importlib
import importlib.util
import json
import os
import subprocess
import sys
import traceback
import structlog
from pathlib import Path
from typing import Optional

from config.settings import settings

log = structlog.get_logger(__name__)

# Skills root directory
SKILLS_DIR = settings.brain_dir / "skills"
SKILLS_DIR.mkdir(parents=True, exist_ok=True)

# Skills metadata file
SKILLS_MANIFEST = SKILLS_DIR / "skills_manifest.json"


class Skill:
    """Represents a single executable skill."""

    def __init__(self, name: str, description: str, usage: str,
                 module_path: str, parameters: list[dict] = None,
                 category: str = "general", auto_created: bool = False):
        self.name = name
        self.description = description
        self.usage = usage
        self.module_path = module_path
        self.parameters = parameters or []
        self.category = category
        self.auto_created = auto_created
        self.is_active = True
        self.created_at = None
        self.last_used = None
        self.use_count = 0

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "description": self.description,
            "usage": self.usage,
            "module_path": self.module_path,
            "parameters": self.parameters,
            "category": self.category,
            "auto_created": self.auto_created,
            "is_active": self.is_active,
            "created_at": self.created_at,
            "last_used": self.last_used,
            "use_count": self.use_count,
        }


class SkillCreationResult:
    """Result of a skill creation attempt."""

    def __init__(self):
        self.success = False
        self.skill: Optional[Skill] = None
        self.error: Optional[str] = None
        self.debug_log: list[str] = []
        self.iterations = 0

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "skill": self.skill.to_dict() if self.skill else None,
            "error": self.error,
            "debug_log": self.debug_log,
            "iterations": self.iterations,
        }


class SkillsService:
    """Manages skill discovery, execution, and dynamic creation."""

    def __init__(self, llm_service):
        self._llm = llm_service
        self._skills: dict[str, Skill] = {}
        self._creation_tasks: dict[str, SkillCreationResult] = {}
        self._max_debug_iterations = 5

    async def initialize(self):
        """Discover and load existing skills."""
        SKILLS_DIR.mkdir(parents=True, exist_ok=True)
        await self._discover_skills()
        log.info(f"Skills service initialized: {len(self._skills)} skills loaded")

    async def _discover_skills(self):
        """Scan skills directory and load skill metadata."""
        if not SKILLS_DIR.exists():
            return

        # Load from manifest if it exists
        if SKILLS_MANIFEST.exists():
            try:
                manifest = json.loads(SKILLS_MANIFEST.read_text(encoding="utf-8"))
                for skill_data in manifest.get("skills", []):
                    skill = Skill(**skill_data)
                    self._skills[skill.name] = skill
            except Exception as e:
                log.warning(f"Failed to load skills manifest: {e}")

        # Also scan for Python modules
        for py_file in SKILLS_DIR.glob("*.py"):
            if py_file.name.startswith("_"):
                continue
            skill_name = py_file.stem
            if skill_name not in self._skills:
                # Try to parse metadata from docstring
                skill = self._parse_skill_module(py_file)
                if skill:
                    self._skills[skill.name] = skill

    def _parse_skill_module(self, path: Path) -> Optional[Skill]:
        """Parse a Python skill module and extract metadata from docstring."""
        try:
            content = path.read_text(encoding="utf-8")
            # Extract module docstring
            import ast
            tree = ast.parse(content)
            docstring = ast.get_docstring(tree) or ""

            # Parse metadata from docstring (expected format):
            # """
            # Skill: Open WhatsApp
            # Description: Opens WhatsApp and performs messaging tasks
            # Category: communication
            # Usage: open_whatsapp(contact="John", message="Hello")
            # Parameters: contact (str), message (str)
            # """
            metadata = {}
            for line in docstring.split("\n"):
                if ":" in line:
                    key, _, value = line.partition(":")
                    metadata[key.strip().lower()] = value.strip()

            name = metadata.get("skill", path.stem)
            description = metadata.get("description", f"Skill from {path.name}")
            usage = metadata.get("usage", f"{path.stem}()")
            category = metadata.get("category", "general")

            # Parse parameters
            params = []
            param_str = metadata.get("parameters", "")
            if param_str:
                for p in param_str.split(","):
                    p = p.strip()
                    if "(" in p and ")" in p:
                        pname = p[:p.index("(")].strip()
                        ptype = p[p.index("(")+1:p.index(")")].strip()
                        params.append({"name": pname, "type": ptype})
                    else:
                        params.append({"name": p, "type": "str"})

            return Skill(
                name=name,
                description=description,
                usage=usage,
                module_path=str(path),
                parameters=params,
                category=category,
            )
        except Exception as e:
            log.debug(f"Failed to parse skill {path.name}: {e}")
            return None

    def get_all_skills(self) -> list[dict]:
        """Return all registered skills as dicts."""
        return [s.to_dict() for s in self._skills.values()]

    def get_skill(self, name: str) -> Optional[dict]:
        """Get a specific skill by name."""
        skill = self._skills.get(name)
        return skill.to_dict() if skill else None

    def delete_skill(self, name: str) -> bool:
        """Delete a skill from memory and filesystem."""
        skill = self._skills.get(name)
        if not skill:
            return False
            
        # Delete the python module if it exists
        try:
            if skill.module_path and os.path.exists(skill.module_path):
                os.remove(skill.module_path)
        except Exception as e:
            log.warning(f"Failed to delete skill file {skill.module_path}: {e}")
            
        # Remove from dictionary
        del self._skills[name]
        
        # Save manifest and regenerate markdown
        self._save_manifest()
        asyncio.create_task(self._update_skills_md())
        
        log.info(f"Deleted skill: {name}")
        return True

    async def execute_skill(self, name: str, params: dict = None) -> dict:
        """Execute a skill by name with given parameters.

        Args:
            name: Skill name to execute.
            params: Dict of parameters to pass to the skill.

        Returns:
            dict with 'success', 'output', and 'error' fields.
        """
        skill = self._skills.get(name)
        if not skill:
            return {"success": False, "error": f"Skill '{name}' not found", "output": ""}

        if not skill.is_active:
            return {"success": False, "error": f"Skill '{name}' is disabled", "output": ""}

        try:
            module_path = Path(skill.module_path)
            if not module_path.exists():
                return {"success": False, "error": f"Skill module not found: {module_path}", "output": ""}

            # Execute the skill in a subprocess for safety
            code = module_path.read_text(encoding="utf-8")

            # Build execution wrapper
            param_str = json.dumps(params or {})
            wrapper = f"""
import json
import sys
sys.path.insert(0, r"{str(module_path.parent)}")

params = json.loads('''{param_str}''')

# Import and execute the skill module
{code}

# Call the main function if it exists
if 'execute' in dir():
    result = execute(**params)
    print(json.dumps({{"result": str(result)}}))
elif 'main' in dir():
    result = main(**params)
    print(json.dumps({{"result": str(result)}}))
else:
    print(json.dumps({{"result": "Skill executed (no main/execute function)"}}))
"""
            result = subprocess.run(
                [sys.executable, "-c", wrapper],
                capture_output=True, text=True, timeout=60,
                env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            )

            import datetime
            skill.last_used = datetime.datetime.now().isoformat()
            skill.use_count += 1
            self._save_manifest()

            if result.returncode == 0:
                return {"success": True, "output": result.stdout.strip(), "error": ""}
            else:
                return {"success": False, "output": result.stdout, "error": result.stderr}

        except subprocess.TimeoutExpired:
            return {"success": False, "error": "Skill execution timed out (60s)", "output": ""}
        except Exception as e:
            return {"success": False, "error": str(e), "output": ""}

    async def create_skill(
        self,
        task_description: str,
        skill_name: Optional[str] = None,
    ) -> SkillCreationResult:
        """Dynamically create a new skill from a task description.

        The creation pipeline:
        1. Generate Python module from task description
        2. Test the module
        3. If errors, debug and fix (up to max_debug_iterations)
        4. Save to skills directory
        5. Register as active tool

        Args:
            task_description: What the skill should do.
            skill_name: Optional explicit name for the skill.

        Returns:
            SkillCreationResult with success status and details.
        """
        result = SkillCreationResult()

        if not self._llm.is_ready:
            result.error = "LLM service not ready"
            return result

        # 1. Generate skill name if not provided
        if not skill_name:
            skill_name = await self._generate_skill_name(task_description)

        skill_name = skill_name.replace(" ", "_").lower()
        module_path = SKILLS_DIR / f"{skill_name}.py"

        result.debug_log.append(f"Creating skill: {skill_name}")
        result.debug_log.append(f"Task: {task_description}")

        # 2. Generate the initial skill code
        code = await self._generate_skill_code(task_description, skill_name)
        if not code:
            result.error = "Failed to generate skill code"
            return result

        result.debug_log.append(f"Generated {len(code)} chars of code")

        # 3. Debug loop: test → fix → test until it works
        for iteration in range(self._max_debug_iterations):
            result.iterations = iteration + 1

            # Save current version
            module_path.write_text(code, encoding="utf-8")

            # Test the skill
            test_result = await self._test_skill(module_path)

            if test_result["success"]:
                result.debug_log.append(f"✅ Skill passed test on iteration {iteration + 1}")
                break
            else:
                error = test_result.get("error", "Unknown error")
                result.debug_log.append(f"❌ Iteration {iteration + 1} failed: {error[:200]}")

                if iteration < self._max_debug_iterations - 1:
                    # Fix the code
                    code = await self._fix_skill_code(code, error, task_description)
                    result.debug_log.append(f"🔧 Fixed code, retrying...")
                else:
                    result.error = f"Failed after {self._max_debug_iterations} iterations: {error}"
                    return result

        # 4. Parse and register the skill
        skill = self._parse_skill_module(module_path)
        if not skill:
            skill = Skill(
                name=skill_name,
                description=task_description,
                usage=f"{skill_name}()",
                module_path=str(module_path),
                category="auto_created",
                auto_created=True,
            )

        import datetime
        skill.created_at = datetime.datetime.now().isoformat()
        skill.auto_created = True
        self._skills[skill_name] = skill
        self._save_manifest()

        result.success = True
        result.skill = skill
        result.debug_log.append(f"✅ Skill '{skill_name}' created and registered")

        # 5. Update skills.md
        await self._update_skills_md()

        return result

    async def _generate_skill_name(self, description: str) -> str:
        """Use LLM to generate a concise skill name."""
        prompt = (
            f"Generate a short, snake_case Python function name for this task:\n"
            f"'{description}'\n\n"
            f"Return ONLY the function name, nothing else. Example: send_whatsapp_message"
        )
        try:
            name = await self._llm.complete(prompt, temperature=0.1, max_tokens=30)
            name = name.strip().replace(" ", "_").replace("-", "_").lower()
            # Remove any non-alphanumeric chars except underscore
            name = "".join(c for c in name if c.isalnum() or c == "_")
            return name[:40] or "custom_skill"
        except Exception:
            return "custom_skill"

    async def _generate_skill_code(self, description: str, name: str) -> Optional[str]:
        """Use LLM to generate a Python skill module."""
        prompt = f'''Generate a complete, self-contained Python skill module for:
Task: {description}

Requirements:
1. The module MUST have a docstring at the top with metadata:
   """
   Skill: {name}
   Description: {description}
   Category: automation
   Usage: {name}(**kwargs)
   Parameters: (list relevant params)
   """

2. Include an `execute(**kwargs)` function as the main entry point
3. Make it GENERIC and REUSABLE — not hardcoded for one specific case
   Example: if the task is "send message to John on WhatsApp", create a general
   "send_whatsapp_message(contact, message)" function that works for ANY contact
4. Use only standard library + pyautogui for GUI automation if needed
5. Include error handling and logging
6. The skill should be scalable for dynamic future use
7. Add `import` statements for all dependencies at the top
8. If using pyautogui, add proper delays and safety checks

Return ONLY the Python code, no markdown fences or explanations.'''

        try:
            code = await self._llm.complete(prompt, temperature=0.3, max_tokens=2000)
            # Clean up markdown fences if present
            code = code.strip()
            if code.startswith("```python"):
                code = code[len("```python"):].strip()
            if code.startswith("```"):
                code = code[3:].strip()
            if code.endswith("```"):
                code = code[:-3].strip()
            return code
        except Exception as e:
            log.error(f"Skill code generation failed: {e}")
            return None

    async def _test_skill(self, module_path: Path) -> dict:
        """Test a skill module by importing and basic syntax check."""
        try:
            # Syntax check
            code = module_path.read_text(encoding="utf-8")
            compile(code, str(module_path), "exec")

            # Import check in subprocess (safe)
            test_code = f"""
import sys
sys.path.insert(0, r"{str(module_path.parent)}")
import importlib.util
spec = importlib.util.spec_from_file_location("test_skill", r"{str(module_path)}")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
# Check that execute or main exists
if not hasattr(mod, 'execute') and not hasattr(mod, 'main'):
    print("WARNING: No execute() or main() function found")
else:
    print("OK: Skill module loaded successfully")
"""
            result = subprocess.run(
                [sys.executable, "-c", test_code],
                capture_output=True, text=True, timeout=15,
                env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            )

            if result.returncode == 0:
                return {"success": True, "output": result.stdout}
            else:
                return {"success": False, "error": result.stderr or result.stdout}

        except SyntaxError as e:
            return {"success": False, "error": f"Syntax error: {e}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def _fix_skill_code(self, code: str, error: str, original_task: str) -> str:
        """Use LLM to fix broken skill code."""
        prompt = f"""Fix this Python skill module. The original task was:
{original_task}

Current code:
```python
{code}
```

Error:
{error[:500]}

Fix ALL errors. Return ONLY the corrected Python code, no markdown fences.
Make sure:
1. All imports are valid
2. There's an execute() function
3. No syntax errors
4. Proper error handling"""

        try:
            fixed = await self._llm.complete(prompt, temperature=0.1, max_tokens=2000)
            fixed = fixed.strip()
            if fixed.startswith("```python"):
                fixed = fixed[len("```python"):].strip()
            if fixed.startswith("```"):
                fixed = fixed[3:].strip()
            if fixed.endswith("```"):
                fixed = fixed[:-3].strip()
            return fixed
        except Exception:
            return code  # Return original if fix fails

    def _save_manifest(self):
        """Save skills manifest to disk."""
        manifest = {
            "skills": [s.to_dict() for s in self._skills.values()],
        }
        try:
            SKILLS_MANIFEST.write_text(
                json.dumps(manifest, indent=2, default=str),
                encoding="utf-8",
            )
        except Exception as e:
            log.error(f"Failed to save skills manifest: {e}")

    async def _update_skills_md(self):
        """Update the skills.md file with all available skills."""
        md_lines = [
            "# 🛠️ AI OS Skills\n",
            "Auto-generated skill registry. Updated dynamically.\n",
            "---\n",
        ]

        categories: dict[str, list[Skill]] = {}
        for skill in self._skills.values():
            cat = skill.category or "general"
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(skill)

        for cat, skills in sorted(categories.items()):
            md_lines.append(f"\n## {cat.replace('_', ' ').title()}\n")
            for skill in skills:
                status = "✅" if skill.is_active else "❌"
                auto = " 🤖" if skill.auto_created else ""
                md_lines.append(f"### {status} {skill.name}{auto}\n")
                md_lines.append(f"**Description:** {skill.description}\n")
                md_lines.append(f"**Usage:** `{skill.usage}`\n")
                if skill.parameters:
                    md_lines.append("**Parameters:**\n")
                    for p in skill.parameters:
                        md_lines.append(f"- `{p.get('name', '')}` ({p.get('type', 'str')})\n")
                md_lines.append(f"**Used:** {skill.use_count} times\n")
                md_lines.append("")

        skills_md_path = SKILLS_DIR / "skills.md"
        skills_md_path.write_text("\n".join(md_lines), encoding="utf-8")
        log.info(f"Updated skills.md with {len(self._skills)} skills")

    def get_creation_status(self, task_id: str) -> Optional[dict]:
        """Get the status of a skill creation task."""
        result = self._creation_tasks.get(task_id)
        return result.to_dict() if result else None
