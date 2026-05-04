@echo off
:: sync_backend.bat
:: Usage: sync_backend.bat <source_dir> <exe_dir>
:: Called by CMake POST_BUILD — copies backend source next to the exe.
:: Preserves existing .venv (user's installed packages).

set SRC=%~1
set DST=%~2\backend

echo [Cyborg] Syncing backend: %SRC% -^> %DST%

robocopy "%SRC%" "%DST%" /E ^
  /XD .venv __pycache__ logs cache checkpoints ^
  /XF *.pyc *.pyo ^
  /NFL /NDL /NJH /NJS /nc /ns /np

:: robocopy returns 1 when files were copied successfully — treat as success
if %ERRORLEVEL% LEQ 7 (
  echo [Cyborg] Backend synced OK.
  exit /b 0
)
echo [Cyborg] WARNING: robocopy returned %ERRORLEVEL%
exit /b 0
