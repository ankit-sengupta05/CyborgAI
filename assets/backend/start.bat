@echo off
setlocal EnableDelayedExpansion
title Cyborg Backend v17.0.0

echo ============================================================
echo    Cyborg Backend v17.0.0
echo ============================================================
echo.

cd /d "%~dp0"

REM ── Delete corrupted venv if pip was interrupted mid-install ──
IF EXIST ".venv\Lib\site-packages\~ip" (
    echo [WARN] Corrupted pip detected. Deleting and recreating venv...
    rmdir /s /q ".venv"
)

REM ── Detect Python (try py launcher first, then python) ────────
py -3 --version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    set PYEXE=py -3
    set VENVPY=py -3 -m venv
    goto :foundpy
)
python --version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    set PYEXE=python
    set VENVPY=python -m venv
    goto :foundpy
)
python3 --version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    set PYEXE=python3
    set VENVPY=python3 -m venv
    goto :foundpy
)

echo [ERROR] Python 3.10+ not found.
echo         Download from: https://www.python.org/downloads/
echo         Make sure to check "Add Python to PATH" during install.
pause
exit /b 1

:foundpy
echo [OK] Python found

REM ── Create virtual environment ────────────────────────────────
IF NOT EXIST ".venv\" (
    echo [INFO] Creating virtual environment...
    %VENVPY% .venv
    IF ERRORLEVEL 1 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo [OK] Virtual environment created
)

REM ── Activate venv ─────────────────────────────────────────────
call .venv\Scripts\activate.bat
IF ERRORLEVEL 1 (
    echo [ERROR] Failed to activate virtual environment.
    pause
    exit /b 1
)

REM ── Upgrade pip safely ────────────────────────────────────────
echo [INFO] Upgrading pip...
python -m pip install --upgrade pip --quiet 2>nul
REM Ignore pip upgrade errors — not critical

REM ── Install / update dependencies ────────────────────────────
echo [INFO] Installing dependencies...
echo        (First run takes 3-5 mins — downloading packages)
echo.
python -m pip install -r requirements.txt
IF ERRORLEVEL 1 (
    echo.
    echo [ERROR] Dependency installation failed.
    echo.
    echo Common fixes:
    echo   1. Delete .venv folder and run start.bat again
    echo   2. Check your internet connection
    echo   3. See SETUP.md for manual install steps
    echo.
    pause
    exit /b 1
)
echo.
echo [OK] All dependencies installed

REM ── Create required directories ──────────────────────────────
if not exist "data"         mkdir data
if not exist "models"       mkdir models
if not exist "checkpoints"  mkdir checkpoints
if not exist "logs"         mkdir logs
if not exist "cache"        mkdir cache
if not exist "config"       mkdir config
if not exist "external"     mkdir external

REM ── Create .env from template if missing ─────────────────────
IF NOT EXIST ".env" (
    IF EXIST ".env.example" (
        copy ".env.example" ".env" >nul
        echo [INFO] Created .env — edit it to add your Firebase service account path.
    )
)

echo.
echo ============================================================
echo    Backend running at: http://127.0.0.1:8765
echo    API docs at:        http://127.0.0.1:8765/api/docs
echo    Press Ctrl+C to stop
echo ============================================================
echo.

REM ── Start uvicorn ─────────────────────────────────────────────
python -m uvicorn main:app --host 127.0.0.1 --port 8765 --reload --log-level info

pause
