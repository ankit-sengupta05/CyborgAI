#!/usr/bin/env bash
# Cyborg Backend Start Script — Linux / macOS
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}   Cyborg Backend v17.0.0${NC}"
echo -e "${GREEN}============================================================${NC}"

command -v python3 &>/dev/null || { echo -e "${RED}[ERROR] Python 3.10+ required.${NC}"; exit 1; }
echo -e "${GREEN}[OK] $(python3 --version)${NC}"

if [ ! -d ".venv" ]; then
    echo -e "${YELLOW}[INFO] Creating virtual environment...${NC}"
    python3 -m venv .venv
fi

source .venv/bin/activate

echo -e "${YELLOW}[INFO] Upgrading pip...${NC}"
python -m pip install --quiet --upgrade pip

echo -e "${YELLOW}[INFO] Installing dependencies...${NC}"
python -m pip install --quiet -r requirements.txt

mkdir -p data models checkpoints logs cache config external

[ ! -f ".env" ] && [ -f ".env.example" ] && cp .env.example .env && echo -e "${YELLOW}[INFO] Created .env from template${NC}"

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}   Backend starting on http://127.0.0.1:8765${NC}"
echo -e "${GREEN}   API Docs: http://127.0.0.1:8765/api/docs${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

python -m uvicorn main:app \
    --host 127.0.0.1 \
    --port 8765 \
    --reload \
    --log-level info
