"""
Agent Tools — Code execution, file I/O, system info.
Registered as LangChain tools for use inside LangGraph agents.
"""
import subprocess
import tempfile
import os
import sys
from pathlib import Path
from langchain_core.tools import tool


@tool
def run_python(code: str) -> str:
    """Execute Python code in a sandboxed subprocess. Returns stdout + stderr."""
    with tempfile.NamedTemporaryFile(
        suffix=".py", delete=False, mode="w", encoding="utf-8"
    ) as f:
        f.write(code)
        tmp_path = f.name
    try:
        result = subprocess.run(
            [sys.executable, tmp_path],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
        output = result.stdout + (("\n" + result.stderr) if result.stderr else "")
        return (output.strip() or "(no output)")[:4096]
    except subprocess.TimeoutExpired:
        return "Execution timed out (30s)"
    except Exception as e:
        return f"Execution error: {e}"
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


@tool
def read_file(path: str) -> str:
    """Read text content of a local file (first 8 KB)."""
    try:
        p = Path(path)
        if not p.exists():
            return f"File not found: {path}"
        if p.stat().st_size > 1_000_000:
            return "File too large (>1MB)"
        return p.read_text(errors="ignore")[:8192]
    except Exception as e:
        return f"Error: {e}"


@tool
def write_file(path: str, content: str) -> str:
    """Write text content to a local file."""
    try:
        p = Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        return f"Written {len(content)} chars to {path}"
    except Exception as e:
        return f"Error: {e}"


@tool
def list_directory(path: str = ".") -> str:
    """List files and subdirectories (up to 100 entries)."""
    try:
        p = Path(path)
        if not p.exists():
            return f"Not found: {path}"
        items = sorted(p.iterdir(), key=lambda x: (x.is_file(), x.name))
        return "\n".join(
            ("📁 " if i.is_dir() else "📄 ") + i.name for i in items[:100]
        ) or "(empty)"
    except Exception as e:
        return f"Error: {e}"


@tool
def get_system_info() -> str:
    """Get current CPU, RAM, disk, and platform info."""
    import platform
    try:
        import psutil
        cpu = psutil.cpu_percent(interval=0.5)
        mem = psutil.virtual_memory()
        disk = psutil.disk_usage("/")
        return (
            f"OS: {platform.system()} {platform.release()}\n"
            f"CPU: {psutil.cpu_count()} cores @ {cpu:.1f}%\n"
            f"RAM: {mem.used/1e9:.1f}/{mem.total/1e9:.1f} GB ({mem.percent:.0f}%)\n"
            f"Disk: {disk.used/1e9:.1f}/{disk.total/1e9:.1f} GB ({disk.percent:.0f}%)"
        )
    except ImportError:
        return f"OS: {platform.system()} {platform.release()}"


ALL_CODE_TOOLS = [run_python, read_file, write_file, list_directory, get_system_info]
