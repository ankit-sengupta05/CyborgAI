"""
CodeFlow Service
Real code analysis: AST parsing, dependency graphs, complexity scoring, LLM explanations.
Supports Python, JavaScript/TypeScript, Dart.
"""
import ast
import re
import asyncio
import structlog
from pathlib import Path
from dataclasses import dataclass, field

log = structlog.get_logger(__name__)

SUPPORTED_EXTENSIONS = {
    ".py": "python", ".js": "javascript", ".ts": "typescript",
    ".dart": "dart", ".go": "go", ".rs": "rust",
    ".java": "java", ".cpp": "cpp", ".c": "c",
}


@dataclass
class CodeNode:
    id: str
    name: str
    kind: str           # file, class, function, module, import
    language: str
    path: str
    line_start: int = 0
    line_end: int = 0
    complexity: int = 1
    loc: int = 0
    docstring: str = ""
    dependencies: list[str] = field(default_factory=list)
    health_score: float = 100.0

    def to_dict(self) -> dict:
        return {
            "id": self.id, "name": self.name, "kind": self.kind,
            "language": self.language, "path": self.path,
            "line_start": self.line_start, "line_end": self.line_end,
            "complexity": self.complexity, "loc": self.loc,
            "docstring": self.docstring, "dependencies": self.dependencies,
            "health_score": self.health_score,
        }


class CodeFlowService:
    def __init__(self):
        self._project_cache: dict[str, dict] = {}

    async def analyze_project(self, project_path: str) -> dict:
        """Full project analysis: dependencies, metrics, health score."""
        path = Path(project_path)
        if not path.exists():
            return {"error": f"Path not found: {project_path}"}

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(None, self._analyze_sync, path)
        self._project_cache[project_path] = result
        return result

    def _analyze_sync(self, project_path: Path) -> dict:
        nodes: list[CodeNode] = []
        edges: list[dict] = []
        stats = {
            "total_files": 0, "total_loc": 0,
            "languages": {}, "avg_complexity": 0,
        }

        all_files = [
            f for f in project_path.rglob("*")
            if f.is_file() and f.suffix in SUPPORTED_EXTENSIONS
            and not any(skip in str(f) for skip in
                        [".git", "node_modules", "__pycache__",
                         ".dart_tool", "build", ".venv"])
        ][:200]  # cap at 200 files

        for fpath in all_files:
            try:
                lang = SUPPORTED_EXTENSIONS[fpath.suffix]
                code = fpath.read_text(encoding="utf-8", errors="ignore")
                loc = len([line for line in code.split("\n") if line.strip()])
                stats["total_files"] += 1
                stats["total_loc"] += loc
                stats["languages"][lang] = stats["languages"].get(lang, 0) + 1

                file_id = str(fpath.relative_to(project_path)).replace("/", ".")
                file_node = CodeNode(
                    id=file_id, name=fpath.name, kind="file",
                    language=lang, path=str(fpath.relative_to(project_path)),
                    loc=loc,
                )

                # Language-specific analysis
                if lang == "python":
                    self._analyze_python(code, fpath, project_path,
                                         file_node, nodes, edges)
                elif lang in ("javascript", "typescript"):
                    self._analyze_js(code, fpath, project_path,
                                     file_node, nodes, edges)
                elif lang == "dart":
                    self._analyze_dart(code, fpath, project_path,
                                       file_node, nodes, edges)
                else:
                    self._analyze_generic(code, fpath, project_path,
                                          file_node, nodes, edges)

                nodes.append(file_node)
            except Exception as e:
                log.debug(f"Analysis error for {fpath}: {e}")

        # Calculate health scores
        for node in nodes:
            node.health_score = self._calculate_health(node)

        complexities = [n.complexity for n in nodes if n.complexity > 0]
        stats["avg_complexity"] = (
            sum(complexities) / len(complexities) if complexities else 0
        )
        overall_health = (
            sum(n.health_score for n in nodes) / len(nodes)
            if nodes else 100.0
        )

        return {
            "nodes": [n.to_dict() for n in nodes],
            "edges": edges,
            "stats": stats,
            "health_score": round(overall_health, 1),
            "project_path": str(project_path),
        }

    def _analyze_python(self, code: str, fpath: Path, root: Path,
                        file_node: CodeNode, nodes: list, edges: list):
        """Analyze Python using AST."""
        try:
            tree = ast.parse(code)
        except SyntaxError:
            return

        rel = str(fpath.relative_to(root))
        complexity = 1

        for node in ast.walk(tree):
            # Count cyclomatic complexity indicators
            if isinstance(node, (
                ast.If, ast.While, ast.For, ast.ExceptHandler,
                ast.With, ast.Assert, ast.comprehension
            )):
                complexity += 1

            # Extract imports as edges
            if isinstance(node, ast.Import):
                for alias in node.names:
                    edges.append({
                        "source": rel, "target": alias.name,
                        "type": "import", "weight": 1.0,
                    })
                    file_node.dependencies.append(alias.name)

            elif isinstance(node, ast.ImportFrom):
                module = node.module or ""
                edges.append({
                    "source": rel, "target": module,
                    "type": "import_from", "weight": 0.8,
                })
                file_node.dependencies.append(module)

            # Extract classes and functions
            elif isinstance(node, ast.ClassDef):
                docstring = ast.get_docstring(node) or ""
                nodes.append(CodeNode(
                    id=f"{rel}::{node.name}", name=node.name,
                    kind="class", language="python", path=rel,
                    line_start=node.lineno,
                    line_end=getattr(node, "end_lineno", node.lineno),
                    docstring=docstring[:200],
                ))
                edges.append({
                    "source": rel, "target": f"{rel}::{node.name}",
                    "type": "contains", "weight": 0.5,
                })

            elif isinstance(node, ast.FunctionDef):
                docstring = ast.get_docstring(node) or ""
                nodes.append(CodeNode(
                    id=f"{rel}::{node.name}", name=node.name,
                    kind="function", language="python", path=rel,
                    line_start=node.lineno,
                    line_end=getattr(node, "end_lineno", node.lineno),
                    complexity=complexity,
                    docstring=docstring[:200],
                ))

        file_node.complexity = complexity

    def _analyze_js(self, code: str, fpath: Path, root: Path,
                    file_node: CodeNode, nodes: list, edges: list):
        """Analyze JS/TS using regex (no full parser)."""
        rel = str(fpath.relative_to(root))
        complexity = code.count("if ") + code.count("for ") + code.count("while ") + 1

        # Extract imports
        import_pattern = re.compile(
            r"import\s+.*?from\s+['\"]([^'\"]+)['\"]|"
            r"require\s*\(\s*['\"]([^'\"]+)['\"]\s*\)",
            re.MULTILINE
        )
        for m in import_pattern.finditer(code):
            dep = m.group(1) or m.group(2)
            if dep:
                edges.append({
                    "source": rel, "target": dep,
                    "type": "import", "weight": 1.0,
                })
                file_node.dependencies.append(dep)

        # Extract classes and functions
        class_pattern = re.compile(r'(?:class|interface)\s+(\w+)', re.MULTILINE)

        for m in class_pattern.finditer(code):
            nodes.append(CodeNode(
                id=f"{rel}::{m.group(1)}", name=m.group(1),
                kind="class", language="javascript", path=rel,
            ))

        file_node.complexity = min(complexity, 50)

    def _analyze_dart(self, code: str, fpath: Path, root: Path,
                      file_node: CodeNode, nodes: list, edges: list):
        """Analyze Dart files."""
        rel = str(fpath.relative_to(root))
        complexity = (code.count("if ") + code.count("for ") +
                      code.count("while ") + code.count("switch ") + 1)

        import_pat = re.compile(r"import\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
        class_pat = re.compile(r'(?:class|mixin|extension)\s+(\w+)', re.MULTILINE)

        for m in import_pat.finditer(code):
            dep = m.group(1)
            edges.append({"source": rel, "target": dep, "type": "import", "weight": 1.0})
            file_node.dependencies.append(dep)

        for m in class_pat.finditer(code):
            nodes.append(CodeNode(
                id=f"{rel}::{m.group(1)}", name=m.group(1),
                kind="class", language="dart", path=rel,
            ))

        file_node.complexity = min(complexity, 50)

    def _analyze_generic(
        self, code: str, fpath: Path, root: Path,
        file_node: CodeNode, nodes: list, edges: list
    ):
        """Generic analysis for unsupported languages."""
        complexity = max(1, code.count("if ") + code.count("for ") +
                         code.count("while ") + 1)
        file_node.complexity = min(complexity, 50)

    def _calculate_health(self, node: CodeNode) -> float:
        """Calculate 0-100 health score based on metrics."""
        score = 100.0
        # Penalize high complexity
        if node.complexity > 10:
            score -= min(30, (node.complexity - 10) * 2)
        # Penalize huge files
        if node.loc > 500:
            score -= min(20, (node.loc - 500) / 50)
        # Penalize no docstring for classes/functions
        if node.kind in ("class", "function") and not node.docstring:
            score -= 10
        return max(0.0, round(score, 1))

    async def get_file_content(self, file_path: str) -> dict:
        """Get file content with syntax highlighting info."""
        path = Path(file_path)
        if not path.exists():
            return {"error": "File not found"}
        content = path.read_text(encoding="utf-8", errors="ignore")
        lang = SUPPORTED_EXTENSIONS.get(path.suffix, "text")
        loc = len([line for line in content.split("\n") if line.strip()])
        return {
            "content": content, "language": lang,
            "loc": loc, "path": file_path,
            "size_kb": round(path.stat().st_size / 1024, 1),
        }

    async def explain_file(self, file_path: str, llm_service) -> str:
        """Use LLM to explain a code file."""
        data = await self.get_file_content(file_path)
        if "error" in data:
            return data["error"]
        content = data["content"][:4000]
        lang = data["language"]
        prompt = f"""Analyze this {lang} file and provide:
1. What it does (2-3 sentences)
2. Key classes/functions and their purpose
3. Dependencies and why they're needed
4. Potential issues or improvements

FILE: {file_path}
```{lang}
{content}
```
Keep the explanation concise and technical."""
        return await llm_service.complete(prompt, temperature=0.3, max_tokens=600)
