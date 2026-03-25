# CYBORG — File Structure & Setup Guide
# ======================================

## Project folder layout

cyborg/
│
├── cyborg_native_ui.py          ← Main UI  (THIS file — replace with updated)
├── cyborg_network.py            ← Network panel  (THIS file — replace with updated)
├── cyborg_assistant.py          ← RAG brain / LLM pipeline  (unchanged)
├── cyborg_ingest.py             ← Standalone CLI ingestion engine  (unchanged)
├── cyborg_content_index.py      ← Content-aware file indexer  (unchanged)
│
├── models/
│   ├── LLM/
│   │   └── phi3/                ← Phi-3 model weights
│   └── embedding_models/
│       └── text/
│           └── models--sentence-transformers--all-MiniLM-L6-v2/
│               └── snapshots/
│                   └── c9745ed1d9f207416be6d2e6f8de32d1f16199bf/
│
├── qdrant_data/                 ← Vector DB (auto-created)
├── bm25_indexes/                ← BM25 keyword indexes (auto-created)
├── cyborg_index/                ← Content index (auto-created)
│
├── cyborg_facts.json            ← User facts (auto-created)
├── chat_log.txt                 ← Chat history log (auto-created)
├── ingest_hashes.json           ← File deduplication registry (auto-created)
│
└── ~\.cyborg_staging\           ← Pulled files from ADB/wireless (auto-created)
    ├── local_device\            ← Files from local PC index
    ├── POCO_M2_Pro\             ← Files pulled from phone (per device)
    └── manual\                  ← Files ingested via path box


## What changed in this update

### cyborg_native_ui.py  (v10.1)
  - ⚡ INDEX THIS DEVICE button on IngestPanel
    → Auto-detects ALL local drives (C:\, D:\, E:\, etc. on Windows)
    → No path picker — confirmation dialog lists drives, then scans everything
  - AdbFullIndexThread fully rewritten:
    → Auto-detects phone storage volumes via 'adb shell df -h'
    → Scans internal storage + SD card automatically
    → storage_sig emitted with volume info for UI display
    → Progress bar shows files done/total with ETA
  - UnifiedIngestThread routes ALL sources through OCR pipeline:
    → Images: pytesseract OCR
    → Scanned PDFs: page-by-page OCR fallback via pymupdf + pytesseract
    → Audio/Video: Whisper transcription
    → Documents: standard extraction (PDF tiers, DOCX, PPTX, XLSX)
  - Progress bar with ETA on IngestPanel for all ingest operations

### cyborg_network.py  (v4)
  - NetworkPanel._on_full_index completely rewritten:
    → Runs 'adb shell df -h' immediately when button clicked (~1s)
    → Parses all /storage/* mount points
    → Confirmation dialog shows per-volume storage bars + grand total
    → Button says "⚡ INDEX ALL 2 VOLUME(S)" (actual count)
    → Zero path input — fully automatic
  - _fmt_bytes() and _parse_android_size() added at module level


## Dependencies

pip install PyQt6
pip install qdrant-client sentence-transformers
pip install transformers torch bitsandbytes accelerate
pip install pymupdf pypdf pdfplumber
pip install python-docx python-pptx openpyxl
pip install faster-whisper          # or: pip install openai-whisper
pip install pytesseract Pillow      # for OCR (also needs Tesseract binary)

# Tesseract binary (Windows):
# https://github.com/UB-Mannheim/tesseract/wiki
# Install to default path: C:\Program Files\Tesseract-OCR\tesseract.exe

# ffmpeg (for video audio extraction):
# https://ffmpeg.org/download.html
# Add to PATH or place ffmpeg.exe in project folder


## ADB Setup (phone indexing)

1. On phone: Settings → About Phone → tap "Build Number" 7 times
2. Settings → Developer Options → Enable "USB Debugging"
3. Connect phone via USB cable
4. Accept "Allow USB Debugging" prompt on phone
5. Click SCAN in Cyborg — phone appears as USB ADB device
6. Click ⚡ INDEX DEVICE — auto-detects internal + SD card


## Local Device Indexing

1. Click ⚡ INDEX THIS DEVICE in the INGEST ENGINE panel
2. Confirmation dialog shows all detected drives
3. Click ⚡ INDEX ALL DRIVES
4. Cyborg scans every drive, skipping:
   - Windows system dirs (Windows, Program Files, AppData, etc.)
   - Build/cache dirs (.git, node_modules, __pycache__, etc.)
   - Cyborg's own data dirs (qdrant_data, bm25_indexes, etc.)
