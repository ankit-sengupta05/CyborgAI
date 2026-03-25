# CYBORG AI — Personal Intelligence System
### Built by Ankit Sengupta

---

## Overview

Cyborg is a fully local, privacy-first AI assistant that runs entirely on your machine. It ingests your documents, videos, audio recordings, and code, stores them as semantic vectors, and lets you find and query anything using natural language — including finding scenes in videos by description and jumping to exact timestamps.

All computation is local. No data leaves your machine.

---

## File Structure

LLMS/
├── cyborg_native_ui.py       # Main application — run this  
├── cyborg_assistant.py       # AI brain: RAG, LLM, ingest pipeline  
├── cyborg_network.py         # Network device discovery & remote ingest  
├── cyborg_ingest.py          # Standalone large-scale ingest engine (1TB+)  
├── cyborg_content_index.py   # Content-aware file index (description search)  

├── models/  
│   ├── LLM/  
│   │   └── phi3/             # Phi-3 language model (quantized 4-bit)  
│   └── embedding_models/  
│       └── text/  
│           └── models--sentence-transformers--all-MiniLM-L6-v2/  

├── qdrant_data/              # Vector database (auto-created)  
├── bm25_indexes/             # BM25 keyword indexes (auto-created)  
├── cyborg_index/             # File metadata, hashes, checkpoints (auto-created)  

├── cyborg_facts.json         # Personal facts (auto-created)  
├── chat_log.txt              # Chat history (auto-created)  
└── ingest_hashes.json        # Deduplication registry (auto-created)  

---

## Quick Start

### 1. Install dependencies

pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121  
pip install transformers bitsandbytes accelerate  
pip install qdrant-client sentence-transformers  
pip install PyQt6  
pip install pypdf pymupdf pdfplumber  
pip install python-docx python-pptx openpyxl  
pip install faster-whisper  
pip install Pillow pytesseract  

### Optional (Required for media processing)
Install FFmpeg: https://ffmpeg.org/download.html  
Add FFmpeg to system PATH  

---

### 2. Run

python cyborg_native_ui.py  

---

## File Descriptions

### cyborg_native_ui.py — Main Application

PyQt6 desktop UI with a unified interface including chat, ingestion, telemetry, and logs.

---

### cyborg_assistant.py — AI Brain

Handles ingestion, retrieval, and LLM generation.

#### Ingestion Pipeline
1. SHA-256 deduplication  
2. Content extraction (PDF, DOCX, PPTX, XLSX, media, code)  
3. Description generation  
4. Chunking (256 words, overlapping)  
5. Embedding (MiniLM, 384-dim)  
6. Storage (Qdrant + BM25)  

---

#### Retrieval (Hybrid Search)

- Vector search (semantic)  
- BM25 keyword search  
- Description boost (1.25×)  
- Top-k ranking  

---

#### Generation

- Phi-3 Mini (4-bit quantized)  
- Max tokens: 300  
- Streaming output  
- Context-aware responses  

---

#### Qdrant Collections

Text → modality_text  
PDF → modality_pdf  
Audio → modality_audio  
Video → modality_video  
Code → modality_code  
Image → modality_image  
Chat → chat_history  
Facts → user_facts  

---

### cyborg_network.py — Network Manager

Handles LAN discovery and remote ingestion via SMB shares.

---

### cyborg_ingest.py — Bulk Ingestion Engine

Optimized for large-scale datasets.

Usage:

python cyborg_ingest.py index "D:\Data"  
python cyborg_ingest.py search "query"  
python cyborg_ingest.py stats  

---

### cyborg_content_index.py — File Discovery Engine

Lightweight index for searching files by meaning.

---

## How Search Works

### Vector Search
Uses embeddings for semantic similarity.

### BM25
Keyword-based ranking.

### Hybrid Score

final_score = vector_score + (bm25_score * weight)

---

### Timestamp Search (Media)

Returns exact playback segments:

00:23:45 → 00:24:45  

---

## Adding Files

### UI
Open app → Local Ingest → Add path → Click GO  

### Network
Scan → Browse → Select → Ingest  

### CLI
python cyborg_ingest.py index "path"  

---

## Re-indexing

- Automatic via file hash  
- Manual via UI refresh  

---

## Context Management

- Total tokens: ~2047  
- Old chats trimmed automatically  
- Important data stored in vector DB  

---

## Troubleshooting

### GPU Issues
Requires ~4GB VRAM  

Check:
python -c "import torch; print(torch.cuda.is_available())"

---

### No Transcription
pip install faster-whisper  

---

### Network Issues
- Same subnet required  
- Enable file sharing  

---

### SMB Issues
- Enable File and Printer Sharing  
- Check firewall settings  

---

## Dependencies

Core:
torch  
transformers  
bitsandbytes  
accelerate  
sentence-transformers  
qdrant-client  

UI:
PyQt6  

Documents:
pypdf  
pymupdf  
pdfplumber  
python-docx  
python-pptx  
openpyxl  

Media:
faster-whisper  
ffmpeg  

Optional:
Pillow  
pytesseract  

---

## Architecture

INPUT → INGEST → PROCESS → STORE → RETRIEVE → GENERATE → UI  

---

## License

MIT License  

---

## Author

Ankit Sengupta  

---

## Keywords

AI assistant, local AI, RAG, vector search, semantic search, offline AI, privacy AI, document search, video search, Whisper, Qdrant, PyQt6, LLM, personal AI system