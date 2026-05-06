#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess
from pathlib import Path

"""
Cyborg AGI — Standalone Build Script
====================================
This script automates the creation of a distribution-ready Windows folder.
Structure:
  dist/CyborgAI/
    ├── CyborgAI.exe (Flutter UI)
    ├── backend/
    │   ├── main.py (Source)
    │   ├── setup_env.py (Auto-installer)
    │   └── requirements.txt
    └── launch.bat (Universal Launcher)
"""

def run_cmd(cmd, cwd=None, shell=False):
    print(f"Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    result = subprocess.run(cmd, cwd=cwd, shell=shell)
    if result.returncode != 0:
        print(f"Error: Command failed with exit code {result.returncode}")
        sys.exit(1)

def main():
    root_dir = Path(__file__).parent.parent.resolve()
    dist_dir = root_dir / "dist" / "CyborgAI"
    
    # 1. Clean up
    if dist_dir.exists():
        print("Cleaning old build...")
        shutil.rmtree(dist_dir)
    dist_dir.mkdir(parents=True, exist_ok=True)

    # 2. Build Flutter Release
    print("\n--- Building Flutter Windows Release ---")
    run_cmd(["flutter", "build", "windows", "--release"], cwd=root_dir, shell=True)
    
    flutter_build_dir = root_dir / "build" / "windows" / "x64" / "runner" / "Release"
    print(f"Copying Flutter build from {flutter_build_dir}...")
    for item in os.listdir(flutter_build_dir):
        s = flutter_build_dir / item
        d = dist_dir / item
        if s.is_dir():
            shutil.copytree(s, d)
        else:
            shutil.copy2(s, d)

    # 3. Prepare Backend Folder
    print("\n--- Preparing Backend for Distribution ---")
    backend_dist = dist_dir / "assets" / "backend"
    backend_dist.mkdir(parents=True, exist_ok=True)
    
    backend_src = root_dir / "assets" / "backend"
    
    # Copy essential backend files
    ignore_patterns = shutil.ignore_patterns(".venv", "__pycache__", "*.spec", "build", "dist", "*.pyc")
    shutil.copytree(backend_src, backend_dist, dirs_exist_ok=True, ignore=ignore_patterns)

    # 4. Create the Universal Launcher (Batch file)
    print("\n--- Creating Universal Launcher ---")
    launcher_path = dist_dir / "CyborgAI_Launcher.bat"
    launcher_content = """@echo off
setlocal
echo [Cyborg AGI] Initializing system...

:: Check if backend venv exists
if not exist "assets\\backend\\.venv" (
    echo [Cyborg AGI] First-run detected. Setting up Python environment...
    echo [Cyborg AGI] This may take a few minutes depending on your internet and GPU...
    python assets\\backend\\setup_env.py
    if %ERRORLEVEL% NEQ 0 (
        echo [Cyborg AGI] Setup failed. Please check if Python 3.10+ is installed and in PATH.
        pause
        exit /b %ERRORLEVEL%
    )
)

echo [Cyborg AGI] Launching UI...
start "" "CyborgAI.exe"
exit
"""
    launcher_path.write_text(launcher_content)

    # 5. Create a Portable Setup Script (Optional but helpful)
    # This helps users who don't even have Python installed.
    # For now, we assume Python is in path as it's a dev-focused tool.

    print(f"\nSUCCESS! Your standalone app is ready in: {dist_dir}")
    print("To share it, zip the contents of that folder.")
    print("\nNext Steps:")
    print("1. Test by running CyborgAI_Launcher.bat")
    print("2. Use Inno Setup (optional) to create a single setup.exe installer.")

if __name__ == "__main__":
    main()
