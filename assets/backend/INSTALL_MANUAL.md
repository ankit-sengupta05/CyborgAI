# Manual Backend Install (Windows)

Run these in PowerShell inside `cyborg\backend\`:

```powershell
# 1. Delete any broken venv first
Remove-Item -Recurse -Force .venv -ErrorAction SilentlyContinue

# 2. Create fresh venv
py -3 -m venv .venv

# 3. Activate
.venv\Scripts\Activate.ps1

# 4. Upgrade pip
python -m pip install --upgrade pip

# 5. Install packages one group at a time (easier to diagnose issues)
python -m pip install fastapi "uvicorn[standard]" websockets python-multipart httpx
python -m pip install "pydantic>=2.8,<3" "pydantic-settings>=2.4,<3"
python -m pip install "openai>=2.26,<3"
python -m pip install "langchain>=1.2,<2" "langchain-openai>=1.2,<2"
python -m pip install "langgraph>=1.1,<2" "langgraph-checkpoint-sqlite>=3,<4"
python -m pip install sentence-transformers "faiss-cpu>=1.9" numpy networkx python-louvain
python -m pip install "sqlalchemy[asyncio]>=2" aiosqlite alembic
python -m pip install "firebase-admin>=6.5,<8" slowapi
python -m pip install PyPDF2 python-docx markdown Pillow chardet PyGithub psutil PyYAML
python -m pip install python-jose[cryptography] passlib[bcrypt] python-dotenv
python -m pip install structlog rich anyio aiofiles tenacity ujson httpx nvidia-ml-py

# 6. Optional: llama-cpp-python (CPU only)
python -m pip install llama-cpp-python

# 7. Optional: GPU acceleration (NVIDIA)
python -m pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu121

# 8. Create directories and .env
New-Item -ItemType Directory -Force data, models, checkpoints, logs, cache, config, external
Copy-Item .env.example .env -ErrorAction SilentlyContinue

# 9. Start the server
python -m uvicorn main:app --host 127.0.0.1 --port 8765 --reload --log-level info
```

If PowerShell blocks script execution, run first:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
