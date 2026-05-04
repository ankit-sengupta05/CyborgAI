#!/usr/bin/env python3
"""
Cyborg Backend — Environment Setup Bootstrap
============================================
Run with SYSTEM Python (not venv).  Handles:
  1. CUDA version detection via nvidia-smi / nvcc
  2. Virtual environment creation
  3. PyTorch install with the correct CUDA wheel URL
  4. llama-cpp-python install (pre-built CUDA wheels where available)
  5. All remaining requirements.txt dependencies

Outputs JSON lines to stdout so the Flutter SplashScreen can show live progress:
  {"status": "progress", "message": "...", "progress": 0.0-1.0}
  {"status": "done",     "message": "...", "progress": 1.0}
  {"status": "error",    "message": "...", "progress": 0.0}
"""

import sys
import os
import json
import subprocess
import re
import platform
from pathlib import Path

# Global state
G_CUDA_ACTIVE = False


# ── JSON progress emitter ────────────────────────────────────────────────────
def emit(status: str, message: str, progress: float):
    print(json.dumps({
        "status": status,
        "message": message,
        "progress": progress,
        "cuda_active": G_CUDA_ACTIVE
    }), flush=True)


def emit_progress(message: str, progress: float):
    emit("progress", message, progress)


def emit_error(message: str):
    emit("error", message, 0.0)
    sys.exit(1)


def emit_done(message: str):
    emit("done", message, 1.0)


# ── CUDA detection ────────────────────────────────────────────────────────────
def detect_cuda() -> tuple[int | None, int | None]:
    """Returns (major, minor) or (None, None) if no CUDA found."""
    # 1. Try nvidia-smi (most reliable — GPU driver version)
    for cmd in [["nvidia-smi"], ["nvidia-smi.exe"]]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if r.returncode == 0:
                m = re.search(r"CUDA Version:\s*(\d+)\.(\d+)", r.stdout)
                if m:
                    return int(m.group(1)), int(m.group(2))
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    # 2. Try nvcc (toolkit version — may differ from driver)
    try:
        r = subprocess.run(["nvcc", "--version"], capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            m = re.search(r"release\s+(\d+)\.(\d+)", r.stdout)
            if m:
                return int(m.group(1)), int(m.group(2))
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return None, None


# ── CUDA → PyTorch wheel URL mapping ─────────────────────────────────────────
# Maps (major, minor) to the nearest available PyTorch CUDA wheel.
# Update this table as new PyTorch versions are released.
TORCH_WHEEL_MAP = [
    # (min_cuda_key, wheel_tag)   cuda_key = major*10 + minor
    (130, "cu130"),   # CUDA 13.0+ -> Use cu130
    (126, "cu124"),   # CUDA 12.6+ -> Use cu124
    (124, "cu124"),   # CUDA 12.4+
    (121, "cu121"),   # CUDA 12.1+
    (118, "cu118"),   # CUDA 11.8+
]


def cuda_to_wheel_tag(major: int | None, minor: int | None) -> tuple[str, str]:
    """Returns (tag, index_url) e.g. ('cu124', 'https://download.pytorch.org/whl/cu124')."""
    if major is None:
        return "cpu", "https://download.pytorch.org/whl/cpu"

    key = major * 10 + (minor // 10 if minor >= 10 else minor)

    for min_key, tag in TORCH_WHEEL_MAP:
        if key >= min_key:
            return tag, f"https://download.pytorch.org/whl/{tag}"

    # Very old CUDA — fall back to CPU
    return "cpu", "https://download.pytorch.org/whl/cpu"


# ── llama-cpp-python pre-built CUDA wheel URL ─────────────────────────────────
LLAMA_WHEEL_BASE = "https://abetlen.github.io/llama-cpp-python/whl"
LLAMA_SUPPORTED_TAGS = {"cu118", "cu121", "cu124"}


def llama_wheel_url(wheel_tag: str) -> str | None:
    """Returns pre-built wheel index URL for llama-cpp-python, or None to compile."""
    # Force source build for CUDA 13.x to ensure binary compatibility with RTX 50-series
    if wheel_tag == "cu130":
        return None

    # Maps for stable pre-built wheels
    if wheel_tag == "cu126":
        wheel_tag = "cu124"

    if wheel_tag in LLAMA_SUPPORTED_TAGS:
        return f"{LLAMA_WHEEL_BASE}/{wheel_tag}"
    return None


# ── pip runner ────────────────────────────────────────────────────────────────
def run_pip(venv_pip: str, args: list, label: str, prog_start: float, prog_end: float,
            extra_env: dict | None = None):
    """Runs pip with streaming output; emits JSON progress per collected package."""
    env = {**os.environ, **(extra_env or {})}
    process = subprocess.Popen(
        [venv_pip] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
    )
    collected = 0
    for line in process.stdout:
        line = line.strip()
        if not line:
            continue
        print(f"[pip] {line}", file=sys.stderr, flush=True)  # raw to stderr for debugging
        lower = line.lower()
        if any(kw in lower for kw in (
            "collecting", "downloading", "installing",
            "successfully installed"
        )):
            collected += 1
            frac = min(collected / 80.0, 1.0)
            prog = prog_start + frac * (prog_end - prog_start)
            pkg = line.split()[-1] if line.split() else "packages"
            emit_progress(f"{label}: {pkg}", prog)

    process.wait()
    if process.returncode not in (0,):
        emit_error(f"pip failed (exit {process.returncode}) during: {label}")


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    backend_dir = Path(__file__).parent.resolve()
    venv_dir = backend_dir / ".venv"

    emit_progress("Cyborg setup starting…", 0.02)

    # ── 1. Detect CUDA ────────────────────────────────────────────────────────
    emit_progress("Detecting GPU / CUDA version…", 0.05)
    cuda_major, cuda_minor = detect_cuda()

    if cuda_major is None:
        emit_progress("No CUDA GPU found — using CPU-only packages", 0.08)
        wheel_tag = "cpu"
        torch_index = "https://download.pytorch.org/whl/cpu"
    else:
        global G_CUDA_ACTIVE
        G_CUDA_ACTIVE = True
        wheel_tag, torch_index = cuda_to_wheel_tag(cuda_major, cuda_minor)
        emit_progress(
            f"CUDA {cuda_major}.{cuda_minor} detected → PyTorch wheel: {wheel_tag}",
            0.08,
        )

    # ── 2. Create virtual environment ─────────────────────────────────────────
    emit_progress("Installing ultrafast uv package manager…", 0.10)
    subprocess.run(
        [sys.executable, "-m", "pip", "install", "uv", "--quiet"],
        capture_output=True
    )

    venv_python = (
        venv_dir / "Scripts" / "python.exe" if platform.system() == "Windows"
        else venv_dir / "bin" / "python"
    )

    if not venv_python.exists() or not (venv_dir / "pyvenv.cfg").exists():
        emit_progress("Creating virtual environment with uv…", 0.15)
        # Nuke corrupted directory if possible, otherwise rely on --clear
        if venv_dir.exists():
            import shutil
            try:
                shutil.rmtree(venv_dir)
            except Exception:
                pass

        r = subprocess.run(
            [sys.executable, "-m", "uv", "venv", "--clear", str(venv_dir)],
            capture_output=True, text=True
        )
        if r.returncode != 0:
            emit_error(f"uv venv failed: {r.stderr.strip()}")
        emit_progress("Virtual environment created ✓", 0.18)
    else:
        emit_progress("Virtual environment exists ✓", 0.18)

    # Helper function to run uv commands
    def run_uv(args, label, prog_start, prog_end, extra_env=None):
        env = {**os.environ, **(extra_env or {})}
        cmd = (
            [sys.executable, "-m", "uv", "pip"] + args +
            ["--python", str(venv_python)]
        )
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env
        )
        collected = 0
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            print(f"[uv] {line}", file=sys.stderr, flush=True)
            if "Resolved" in line or "Downloaded" in line or "Installed" in line:
                collected += 1
                frac = min(collected / 20.0, 1.0)
                emit_progress(
                    f"{label}: {line[:40]}...",
                    prog_start + frac * (prog_end - prog_start)
                )
        proc.wait()
        if proc.returncode != 0:
            emit_error(f"uv failed during: {label}")

    # ── 3. Install PyTorch with correct CUDA wheel ────────────────────────────
    skip_torch = False
    force_torch = False
    if venv_python.exists():
        try:
            check_script = "import torch; print(torch.cuda.is_available())"
            r = subprocess.run(
                [str(venv_python), "-c", check_script],
                capture_output=True, text=True, timeout=10
            )
            if "True" in r.stdout:
                emit_progress("PyTorch with CUDA already installed ✓", 0.45)
                skip_torch = True
        except Exception:
            pass

    if not skip_torch:
        emit_progress(f"Installing PyTorch ({wheel_tag}) with uv…", 0.20)

        # Check if existing torch is CPU-only (if we didn't skip)
        force_torch = False
        if wheel_tag != "cpu":
            try:
                check_cmd = [
                    str(venv_python), "-c",
                    "import torch; print(torch.cuda.is_available())"
                ]
                r = subprocess.run(check_cmd, capture_output=True, text=True, timeout=10)
                if "False" in r.stdout:
                    emit_progress("CPU-only Torch detected — forcing CUDA reinstall…", 0.21)
                    force_torch = True
            except Exception:
                force_torch = True

        torch_packages = ["torch>=2.6.0", "torchvision", "torchaudio"]
        torch_args = ["install"] + torch_packages + ["--index-url", torch_index]
        if force_torch:
            torch_args.append("--force-reinstall")

        run_uv(
            torch_args,
            "PyTorch", 0.22, 0.45,
        )
        emit_progress("PyTorch installed ✓", 0.45)

    # Uninstall torchcodec to prevent Windows DLL errors in PyTorch 2.6+
    if venv_python.exists():
        subprocess.run(
            [sys.executable, "-m", "uv", "pip", "uninstall", "torchcodec", "-y",
             "--python", str(venv_python)],
            capture_output=True
        )

    # ── 4. Install llama-cpp-python ───────────────────────────────────────────
    skip_llama = False
    # Force reinstall for CUDA 13.x to transition from incompatible wheels to source build
    if wheel_tag == "cu130":
        force_llama = True
        skip_llama = False
    elif venv_python.exists() and not force_torch:
        try:
            # Check if installed AND has GPU support
            check_script = (
                "import llama_cpp; "
                "print(llama_cpp.llama_supports_gpu_offload())"
            )
            r = subprocess.run(
                [str(venv_python), "-c", check_script],
                capture_output=True, text=True, timeout=10
            )
            if "True" in r.stdout:
                emit_progress("llama-cpp-python (CUDA) already installed ✓", 0.55)
                skip_llama = True
            elif "False" in r.stdout and G_CUDA_ACTIVE:
                emit_progress(
                    "llama-cpp-python found but no CUDA support — forcing reinstall…",
                    0.46
                )
                skip_llama = False
                force_llama = True
            elif "ok" in r.stdout or "False" in r.stdout:
                emit_progress("llama-cpp-python (CPU) already installed ✓", 0.55)
                skip_llama = True
        except Exception:
            pass

    if not skip_llama:
        emit_progress("Installing llama-cpp-python with uv…", 0.46)

        # Force llama reinstall if torch was forced (likely DLL/CUDA mapping changed)
        force_llama = force_torch

        llama_index = llama_wheel_url(wheel_tag)
        llama_pkg = "llama-cpp-python>=0.3.1"

        extra_uv_args = ["--force-reinstall"] if force_llama else []

        if llama_index is not None:
            run_uv(
                ["install", llama_pkg, "--extra-index-url", llama_index] + extra_uv_args,
                "llama-cpp-python (prebuilt)", 0.46, 0.55,
            )
        elif wheel_tag != "cpu":
            emit_progress(f"Building llama-cpp-python with CUDA ({wheel_tag})…", 0.47)
            run_uv(
                ["install", llama_pkg] + extra_uv_args,
                "llama-cpp-python (source)", 0.47, 0.55,
                extra_env={"CMAKE_ARGS": "-DGGML_CUDA=on", "FORCE_CMAKE": "1"},
            )
        else:
            run_uv(
                ["install", llama_pkg] + extra_uv_args,
                "llama-cpp-python (CPU)", 0.46, 0.55,
            )
        emit_progress("llama-cpp-python installed ✓", 0.55)

    # ── 5. Install remaining requirements ─────────────────────────────────────
    req_file = backend_dir / "requirements.txt"
    if req_file.exists():
        emit_progress("Installing remaining dependencies with uv…", 0.56)
        run_uv(
            ["install", "-r", str(req_file)],
            "Dependencies", 0.56, 0.94,
        )

    emit_progress("All dependencies installed ✓", 0.95)

    # Fix llama-cpp-python DLLs for Windows CUDA
    if platform.system() == "Windows":
        try:
            # We need to run this inside the newly created venv context
            fix_script = """
import torch
import shutil
import sys
from pathlib import Path
torch_lib = Path(torch.__file__).parent / "lib"
llama_lib = Path(sys.prefix) / "Lib" / "site-packages" / "llama_cpp" / "lib"

if torch_lib.exists() and llama_lib.exists():
    dll_map = {{
        "cudart64_13.dll": "cudart64_12.dll",
        "cublas64_13.dll": "cublas64_12.dll",
        "cublasLt64_13.dll": "cublasLt64_12.dll",
    }}
    for src_name, dst_name in dll_map.items():
        src = torch_lib / src_name
        dst = llama_lib / dst_name
        if src.exists() and not dst.exists():
            shutil.copy2(src, dst)
            print(f"Fixed DLL: {{dst_name}}")
"""
            subprocess.run([str(venv_python), "-c", fix_script], capture_output=True)
        except Exception:
            pass

    emit_done("Environment ready ✓")


if __name__ == "__main__":
    main()
