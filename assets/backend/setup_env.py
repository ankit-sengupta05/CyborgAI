import os
import sys
import subprocess
import json
import platform
import time
from pathlib import Path

# --- Configuration ---
LLAMA_WHEEL_BASE = "https://abetlen.github.io/llama-cpp-python/whl"
TORCH_INDEX = "https://download.pytorch.org/whl/cu124"
# Supported llama-cpp-python wheels
LLAMA_SUPPORTED_TAGS = {"cu118", "cu121", "cu124"}

def emit_progress(message: str, progress: float, cuda: bool = False):
    """Emits JSON progress for the Flutter backend service."""
    print(json.dumps({
        "status": "progress",
        "message": message,
        "progress": progress,
        "cuda_active": cuda
    }), flush=True)

def emit_done(message: str, cuda: bool = False):
    print(json.dumps({
        "status": "done",
        "message": message,
        "progress": 1.0,
        "cuda_active": cuda
    }), flush=True)

def emit_error(message: str):
    print(json.dumps({
        "status": "error",
        "message": message,
        "progress": 0.0,
        "cuda_active": False
    }), flush=True)
    sys.exit(1)

def detect_cuda() -> tuple[int, int] | None:
    """Detects CUDA version via nvcc or nvidia-smi."""
    try:
        # Check nvcc first
        res = subprocess.run(["nvcc", "--version"], capture_output=True, text=True)
        if res.returncode == 0:
            import re
            m = re.search(r"release (\d+)\.(\d+)", res.stdout)
            if m:
                return int(m.group(1)), int(m.group(2))
    except Exception:
        pass

    try:
        # Check nvidia-smi
        res = subprocess.run(["nvidia-smi"], capture_output=True, text=True)
        if res.returncode == 0:
            import re
            m = re.search(r"CUDA Version: (\d+)\.(\d+)", res.stdout)
            if m:
                return int(m.group(1)), int(m.group(2))
    except Exception:
        pass
    
    return None

def get_wheel_tag(major: int, minor: int) -> str:
    """Maps CUDA version to a supported wheel tag."""
    # Update this table as new PyTorch versions are released.
    TORCH_WHEEL_MAP = [
        # (min_cuda_key, wheel_tag)   cuda_key = major*10 + minor
        (132, "cu132"),   # CUDA 13.2+
        (130, "cu130"),   # CUDA 13.0+
        (126, "cu124"),   # CUDA 12.6+
        (124, "cu124"),   # CUDA 12.4+
        (121, "cu121"),   # CUDA 12.1+
        (118, "cu118"),   # CUDA 11.8+
    ]
    
    key = major * 10 + (minor // 10 if minor >= 10 else minor)
    for min_key, tag in TORCH_WHEEL_MAP:
        if key >= min_key:
            return tag
    return "cpu"

def llama_wheel_url(wheel_tag: str) -> str | None:
    """Returns pre-built wheel index URL for llama-cpp-python, or None to compile."""
    if wheel_tag.startswith("cu13"):
        # CUDA 13.x: Fallback to cu124 pre-built wheel (compatible if bridged)
        return f"{LLAMA_WHEEL_BASE}/cu124"

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
    for line in process.stdout:
        line = line.strip()
        if not line:
            continue
        # Only print debug info for users to terminal
        print(f"[pip] {line}", file=sys.stderr, flush=True)
        
        # Heuristic to detect package completion
        if "Collecting" in line:
            pkg = line.split(" ")[1]
            emit_progress(f"{label}: {pkg}", prog_start)
        elif "Installing" in line and "packages" in line:
            emit_progress(f"{label}: Finalizing...", prog_end)
        elif "Successfully installed" in line:
            prog = prog_end
            pkg = line.split(" ")[-1]
            emit_progress(f"{label}: {pkg}", prog)

    process.wait()
    return process.returncode == 0

def main():
    emit_progress("Cyborg setup starting...", 0.02)
    backend_dir = Path(__file__).parent.absolute()
    venv_dir = backend_dir / ".venv"
    
    # ── 1. Detect Environment ────────────────────────────────────────────────
    emit_progress("Detecting GPU / CUDA version...", 0.05)
    cuda_ver = detect_cuda()
    cuda_active = cuda_ver is not None
    wheel_tag = "cpu"
    if cuda_active:
        wheel_tag = get_wheel_tag(*cuda_ver)
        emit_progress(f"CUDA {cuda_ver[0]}.{cuda_ver[1]} detected \u2192 wheel: {wheel_tag}", 0.08, cuda=True)
    else:
        emit_progress("No CUDA detected \u2192 using CPU mode", 0.08, cuda=False)

    # ── 2. Initialize UV ──────────────────────────────────────────────────────
    emit_progress("Installing ultrafast uv package manager...", 0.10, cuda=cuda_active)
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "uv", "--quiet"], check=True)
    except Exception as e:
        emit_error(f"Failed to install uv: {e}")

    # ── 3. Create Venv ────────────────────────────────────────────────────────
    venv_python = (
        venv_dir / "Scripts" / "python.exe" if platform.system() == "Windows"
        else venv_dir / "bin" / "python"
    )
    venv_pip = (
        venv_dir / "Scripts" / "pip.exe" if platform.system() == "Windows"
        else venv_dir / "bin" / "pip"
    )

    if not venv_python.exists() or not (venv_dir / "pyvenv.cfg").exists():
        emit_progress("Creating virtual environment with uv...", 0.15, cuda=cuda_active)
        try:
            subprocess.run([sys.executable, "-m", "uv", "venv", str(venv_dir)], check=True)
            emit_progress("Virtual environment created \u2713", 0.18, cuda=cuda_active)
        except Exception as e:
            emit_error(f"Failed to create venv: {e}")
    else:
        emit_progress("Virtual environment exists \u2713", 0.18, cuda=cuda_active)

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
                    prog_start + frac * (prog_end - prog_start),
                    cuda=cuda_active
                )
        proc.wait()
        return proc.returncode == 0

    # ── 4. Install PyTorch (Heavyweight) ──────────────────────────────────────
    force_torch = False
    try:
        # Check if torch is installed and matches tag
        check_code = f"import torch; print(torch.cuda.is_available() if '{wheel_tag}' != 'cpu' else 'True')"
        res = subprocess.run([str(venv_python), "-c", check_code], capture_output=True, text=True)
        if res.returncode != 0 or "False" in res.stdout:
            force_torch = True
    except Exception:
        force_torch = True

    if force_torch:
        emit_progress(f"Installing PyTorch with CUDA ({wheel_tag})...", 0.20, cuda=cuda_active)
        torch_pkgs = ["torch", "torchvision", "torchaudio"]
        if wheel_tag != "cpu":
            # Fix for cu132: fallback to cu124 for torch as well if cu132 not available
            torch_tag = "cu124" if wheel_tag.startswith("cu13") else wheel_tag
            torch_index = f"https://download.pytorch.org/whl/{torch_tag}"
            run_uv(["install"] + torch_pkgs + ["--index-url", torch_index], "PyTorch", 0.20, 0.45)
        else:
            run_uv(["install"] + torch_pkgs, "PyTorch", 0.20, 0.45)
    else:
        emit_progress("PyTorch with CUDA already installed \u2713", 0.45, cuda=cuda_active)

    # ── 5. Install Llama-cpp-python (Inference Engine) ────────────────────────
    # Check if llama-cpp-python is functional with CUDA
    skip_llama = False
    if not force_torch:
        try:
            check_code = "import llama_cpp; print(llama_cpp.llama_supports_gpu_offload())"
            res = subprocess.run([str(venv_python), "-c", check_code], capture_output=True, text=True)
            if res.returncode == 0 and ("True" in res.stdout or wheel_tag == "cpu"):
                skip_llama = True
        except Exception:
            pass

    if not skip_llama:
        emit_progress("Installing llama-cpp-python with uv...", 0.46, cuda=cuda_active)
        force_llama = force_torch or wheel_tag.startswith("cu13")
        force_source = False # Allow pre-built cu124 wheels for cu13+ if bridged

        llama_index = llama_wheel_url(wheel_tag) if not force_source else None
        llama_pkg = "llama-cpp-python>=0.3.1"
        extra_uv_args = ["--force-reinstall"] if force_llama else []
        if force_source:
            extra_uv_args.extend(["--no-binary", "llama-cpp-python"])
        
        success = False
        if llama_index is not None:
            success = run_uv(
                ["install", llama_pkg, "--extra-index-url", llama_index] + extra_uv_args,
                "llama-cpp-python (prebuilt)", 0.46, 0.55
            )
        elif wheel_tag != "cpu":
            emit_progress(f"Building llama-cpp-python with CUDA ({wheel_tag}) \u2013 This will take 5-10 mins...", 0.47, cuda=cuda_active)
            cuda_path = os.environ.get("CUDA_PATH", r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2")
            cmake_args = f"-DGGML_CUDA=ON -DCUDAToolkit_ROOT=\"{cuda_path}\""
            success = run_uv(
                ["install", llama_pkg] + extra_uv_args + ["--no-cache-dir"],
                "llama-cpp-python (source)", 0.47, 0.55,
                extra_env={"CMAKE_ARGS": cmake_args, "FORCE_CMAKE": "1", "PATH": f"{cuda_path}\\bin;{os.environ['PATH']}"}
            )
        else:
            success = run_uv(["install", llama_pkg] + extra_uv_args, "llama-cpp-python (CPU)", 0.46, 0.55)

        if not success and wheel_tag != "cpu":
            emit_progress("GPU build failed (missing compiler?) \u2192 Falling back to CPU version...", 0.50, cuda=False)
            success = run_uv(["install", llama_pkg, "--force-reinstall"], "llama-cpp-python (CPU fallback)", 0.50, 0.55)
            cuda_active = False # Mark as inactive for status display
        
        if not success:
            emit_error("Failed to install llama-cpp-python even in CPU mode.")
        
        emit_progress("llama-cpp-python installed \u2713", 0.55, cuda=cuda_active)

    # ── 6. Install remaining dependencies ─────────────────────────────────────
    emit_progress("Installing remaining dependencies with uv...", 0.56, cuda=cuda_active)
    run_uv(["install", "-r", str(backend_dir / "requirements.txt")], "Requirements", 0.56, 0.95)

    # ── 7. Bridging DLLs (Windows Only) ──────────────────────────────────────
    if platform.system() == "Windows" and cuda_active:
        emit_progress("Bridging CUDA DLLs from PyTorch to llama_cpp...", 0.96, cuda=True)
        try:
            torch_lib = venv_dir / "Lib" / "site-packages" / "torch" / "lib"
            llama_lib = venv_dir / "Lib" / "site-packages" / "llama_cpp" / "lib"
            
            if torch_lib.exists() and llama_lib.exists():
                import shutil
                dlls_to_bridge = ["cublas64_12.dll", "cublasLt64_12.dll", "cudart64_12.dll"]
                for dll in dlls_to_bridge:
                    src = torch_lib / dll
                    dst = llama_lib / dll
                    if src.exists() and not dst.exists():
                        shutil.copy2(src, dst)
                        print(f"[bridge] Copied {dll} to llama_cpp/lib", file=sys.stderr)
            
            # Also patch the search path for the current process
            os.add_dll_directory(str(llama_lib))
        except Exception as e:
            print(f"[bridge] Warning: Failed to bridge DLLs: {e}", file=sys.stderr)

    # ── 8. Finalize ───────────────────────────────────────────────────────────
    emit_done("Environment ready \u2713", cuda=cuda_active)

if __name__ == "__main__":
    main()
