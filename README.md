# CYBORG AI — Personal Intelligence System
### Built by Ankit Sengupta

---

## Overview

Cyborg is a fully local, privacy-first AI assistant that runs entirely on your machine. It ingests your documents, videos, audio recordings, and code, stores them as semantic vectors, and lets you find and query anything using natural language — including finding scenes in videos by description and jumping to exact timestamps.

All computation is local. No data leaves your machine.

---

## File Structure

```
LLMS/
├── cyborg_native_ui.py       ← Main application — run this
├── cyborg_assistant.py       ← AI brain: RAG, LLM, ingest pipeline
├── cyborg_network.py         ← Network device discovery & remote ingest
├── cyborg_ingest.py          ← Standalone large-scale ingest engine (1TB+)
├── cyborg_content_index.py   ← Content-aware file index (description search)
│
├── models/
│   ├── LLM/
│   │   └── phi3/             ← Phi-3 language model (quantized 4-bit)
│   └── embedding_models/
│       └── text/
│           └── models--sentence-transformers--all-MiniLM-L6-v2/
│
├── qdrant_data/              ← Vector database (auto-created)
├── bm25_indexes/             ← BM25 keyword indexes (auto-created)
├── cyborg_index/             ← File metadata, hashes, checkpoints (auto-created)
│
├── cyborg_facts.json         ← Personal facts about you (auto-created)
├── chat_log.txt              ← Persistent chat history (auto-created)
└── ingest_hashes.json        ← File deduplication registry (auto-created)
```

---

## Quick Start

### 1. Install dependencies

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install transformers bitsandbytes accelerate
pip install qdrant-client sentence-transformers
pip install PyQt6
pip install pypdf pymupdf pdfplumber
pip install python-docx python-pptx openpyxl
pip install faster-whisper          # for video/audio transcription
pip install Pillow pytesseract       # for image OCR (optional)
```

For network device ingest (Windows):
```
# SMB share access is built into Windows — no extra install needed
# Just enable file sharing on the remote device
```

### 2. Run

```bash
python cyborg_native_ui.py
```

---

## File Descriptions

---

### `cyborg_native_ui.py` — Main Application Window

The PyQt6 desktop UI. Single window, no separate windows to manage — everything is visible at once via splitter panels.

**Layout:**

```
┌─────────────────────────────────────────────────────────────────────────┐
│  TITLEBAR: CYBORG  ●LIVE  VRAM  UPTIME  TOK/S  CTX%     [─][□][✕]     │
├──────────────────┬──────────────────────────────┬───────────────────────┤
│  NEURAL ORB      │                              │  GPU TELEMETRY        │
│                  │   CHAT / NEURAL INTERFACE    │  (arc gauges + bars)  │
│  [DISP ON]       │                              │                       │
│  dispersion ──── │   User and AI bubbles        ├───────────────────────┤
│                  │   with citation badges       │  VECTOR DB            │
├──────────────────┤   and timestamp jump buttons │  (per-collection      │
│  [LOCAL INGEST]  │                              │   counts + DEL/↺)     │
│  [NETWORK DEVICES│                              │                       │
│   tab]           │   [input box]  [SEND]        │                       │
├──────────────────┴──────────────────────────────┴───────────────────────┤
│  UNIFIED LOG  (scrolling activity feed)                          [CLR]  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Panels:**

| Panel | Location | Purpose |
|---|---|---|
| Neural Orb | Top-left | Animated 3D grid orb, pauses during LLM inference to free GPU |
| Chat | Centre | Streaming chat with citation badges and timestamp jump buttons |
| Local Ingest | Bottom-left tab 1 | Ingest local files/folders into RAG |
| Network Devices | Bottom-left tab 2 | Discover LAN devices, browse shares, ingest remotely |
| GPU Telemetry | Top-right | VRAM usage, token/s, context fill % |
| Vector DB | Bottom-right | Per-modality vector counts, wipe, re-ingest |
| Unified Log | Bottom | All system events in one scrolling feed |

**Keyboard shortcuts:**

| Key | Action |
|---|---|
| `Enter` | Send chat message |
| `Shift+Enter` | New line in chat input |
| `F11` | Toggle fullscreen |
| `Ctrl+Q` | Quit |
| `Ctrl+E` | Open error console |

---

### `cyborg_assistant.py` — AI Brain

The core intelligence module. Handles everything from file ingestion to LLM generation.

**Key components:**

#### Ingestion pipeline (`ingest_file`)
Every file goes through this pipeline:
1. **Deduplication** — SHA-256 hash check. Skips unchanged files entirely.
2. **Content extraction** — format-specific extractors:
   - PDF → pymupdf (structure-aware) → pypdf → pdfplumber (3-tier fallback)
   - DOCX → python-docx with table extraction
   - PPTX → python-pptx slide-by-slide with notes
   - XLSX → openpyxl with sheet names
   - Audio/Video → Whisper transcription with timestamps
   - Code/Text → direct read with binary detection
3. **Description generation** — creates a rich semantic summary from content. This is what makes `"show me my resume"` find `scan001.pdf` — the description captures document type, technologies, subjects, section headings, and a content preview.
4. **Chunking** — 256-word overlapping chunks on paragraph boundaries.
5. **Embedding** — sentence-transformers all-MiniLM-L6-v2 (384 dimensions).
6. **Storage** — Qdrant vector DB (on-disk) + BM25 keyword index.

#### Retrieval (`hybrid_retrieve`)
For every chat query:
1. Vector search across all collections (top-6 per collection)
2. BM25 keyword search (top-6)
3. Description chunks get 1.25× score boost
4. Deduplicated, ranked, trimmed to FINAL_TOP_K=4 chunks
5. Media chunks include `@ 01:23:45 → 01:24:45` timestamp in context

#### Generation (`generate_response_stream`)
- Phi-3 Mini 4-bit quantized (BitsAndBytes NF4)
- 300 max new tokens, temperature 0.35
- Context window: 2047 tokens total
- Streaming via QueueStreamer → UI polls every 16ms
- Identity injection: strips any Microsoft/Phi leakage, replaces with "Cyborg"

#### Qdrant collections

| Key | Collection Name | Contents |
|---|---|---|
| `text` | `modality_text` | TXT, MD, DOCX, XLSX, CSV |
| `pdf` | `modality_pdf` | PDF files |
| `audio` | `modality_audio` | MP3, WAV, FLAC etc. (transcripts) |
| `video` | `modality_video` | MP4, MKV etc. (transcripts) |
| `code` | `modality_code` | Python, JS, SQL etc. |
| `image` | `modality_image` | PNG, JPG etc. (OCR text) |
| `chat` | `chat_history` | Conversation history |
| `facts` | `user_facts` | Personal facts about user |

---

### `cyborg_network.py` — Network Device Manager

Handles discovery and remote ingest from other machines on your network.

**How device discovery works:**

```
Cyborg machine
    │
    ├── Ping sweep all IPs in /24 subnet (parallel, 64 threads)
    ├── Read ARP table → get MAC addresses
    ├── Resolve hostnames (parallel DNS)
    ├── Check port 47392 → Cyborg wireless agent? (future)
    └── Every 30 seconds → repeat
```

**Remote ingest flow:**

```
Click BROWSE on device card
    │
    ├── net view \\IP → list SMB shares
    ├── Navigate folder tree (UNC paths)
    ├── Multi-select files
    └── Click INGEST SELECTED
            │
            ├── RemoteIngestThread starts
            ├── shutil.copy2(\\IP\share\file → ~/.cyborg_staging\device\)
            └── cyborg_assistant.ingest_file(local_copy)
                    └── Full pipeline runs locally
```

**Device card shows:**
- IP address + hostname
- MAC address + vendor guess (OUI lookup)
- `⚡ CYBORG` badge if wireless agent is running (future)
- `THIS MACHINE` badge for the local machine
- Last seen timestamp
- BROWSE and PING buttons

**Future wireless mode:**
The `WIRELESS READY` badge in the UI and port 47392 are reserved for a future Flutter app that will broadcast device info over the LAN. The `_check_cyborg_agent()` function already queries this port — when the app is built, it will Just Work with no UI changes needed.

**Setup on remote Windows devices:**
1. Right-click folder → Properties → Sharing → Share
2. Add "Everyone" with Read permission
3. Ensure Windows Firewall allows File and Printer Sharing
4. Both machines must be on the same subnet

---

### `cyborg_ingest.py` — Large-Scale Ingest Engine

Standalone ingestion optimised for 1TB+ datasets. Use this for bulk initial indexing, then use `cyborg_assistant.py`'s pipeline for day-to-day additions.

**Key optimisations:**

| Optimisation | Detail |
|---|---|
| On-disk vectors | Qdrant `on_disk=True` — vectors never loaded into RAM |
| mmap threshold | After 20k vectors, switches to memory-mapped access |
| Hash fast-path | mtime+size check before SHA-256 — skips I/O on unchanged files |
| GPU batching | 512 chunks per embedding call |
| Parallel workers | 4 file processing threads (I/O bound) |
| Checkpointing | Saves progress every 100 files — resume after crash |
| VAD filtering | Whisper skips silence segments — faster transcription |
| No text in Qdrant | Text stored only in BM25, not Qdrant payload — saves ~70% storage |

**CLI usage:**
```bash
# Index a folder
python cyborg_ingest.py index "D:\Lectures" --workers 4

# Index only specific extensions
python cyborg_ingest.py index "E:\Documents" --ext .pdf .docx .pptx

# Search by description
python cyborg_ingest.py search "scene where the car crashes"
python cyborg_ingest.py search "gradient descent explanation" --type video
python cyborg_ingest.py search "my resume" --open

# Show stats
python cyborg_ingest.py stats
```

**Storage estimate:**
| Files | Avg chunks/file | Vectors | Approx DB size |
|---|---|---|---|
| 10,000 | 5 | 50,000 | ~75 MB |
| 100,000 | 5 | 500,000 | ~750 MB |
| 500,000 | 5 | 2,500,000 | ~3.7 GB |

---

### `cyborg_content_index.py` — Content-Aware File Index

Lighter-weight index focused on file discovery by content description. Designed for the `"show me my resume"` use case across an entire file system.

**Difference from `cyborg_ingest.py`:**

| Feature | `cyborg_ingest.py` | `cyborg_content_index.py` |
|---|---|---|
| Focus | Deep content search | File discovery |
| Chunks per file | All content chunks | Description + content |
| Video/Audio | Full timestamp chunks | Description only |
| Scale target | 1TB+ | Whole filesystem |
| BM25 | Yes | Yes |
| Use case | "Explain gradient descent from my lecture" | "Find all my resumes" |

**CLI usage:**
```bash
python cyborg_content_index.py index "C:\Users\ankit\Documents"
python cyborg_content_index.py search "show me my resume"
python cyborg_content_index.py search "lecture notes on probability"
python cyborg_content_index.py stats
```

---

## How Search Works

### Vector search
Every chunk of text is embedded into a 384-dimensional vector. Similar meaning → similar vector → high cosine similarity score. This finds content regardless of exact wording.

```
Query: "show me my resume"
   ↓ embed
[0.12, -0.34, 0.67, ...]
   ↓ cosine similarity against all stored vectors
Top matches:
  scan001.pdf description chunk:
    "Document type: resume/CV | Technologies: Python, PyTorch |
     Sections: WORK EXPERIENCE, EDUCATION, SKILLS"
  Score: 0.847  ← high match
```

### BM25 search
Classic keyword search that handles exact term matching — complements vector search for technical terms and proper nouns.

### Hybrid scoring
```
final_score = vector_score * 1.25 (if description chunk)
            + bm25_score_normalized * 0.25
```

### Timestamp search (audio/video)
```
Query: "scene where they discuss the contract"
   ↓
Whisper transcript chunks:
  chunk_14: "...so the terms of the contract state that..."
            start: 00:23:45, end: 00:24:45
  Score: 0.72

Result shown in UI:
  ⏱ 00:23:45 → 00:24:45
  [▶ JUMP TO 00:23:45]  ← opens VLC at that exact second
```

---

## Adding New Files

**Via UI:**
1. Open the app
2. Bottom-left: `LOCAL INGEST` tab
3. Type or paste the file/folder path
4. Click `GO`
5. Watch progress in the LIVE FEED and UNIFIED LOG

**Via network device:**
1. Bottom-left: `NETWORK DEVICES` tab
2. Click `⟳ SCAN`
3. Click `📁 BROWSE` on a device
4. Navigate to the folder, select files
5. Click `⬇ INGEST SELECTED`

**Via command line:**
```bash
python cyborg_ingest.py index "C:\path\to\folder"
```

---

## Re-indexing Changed Files

The system tracks SHA-256 hashes of every ingested file. If you modify a file and re-ingest it:
1. Old vectors for that file are deleted from Qdrant
2. New vectors are generated from the updated content
3. Hash registry is updated

To force re-index without changing the file, use the `↺` button next to any collection in the Vector DB panel.

---

## Context Window Management

The LLM has a 2047-token context window split as:
```
2047 total
 - 300 max new tokens (response)
 - 100 safety margin
 - N  persona tokens (~150)
 - N  document context (retrieved chunks)
 - N  chat history (trimmed to fit)
 ─────────────────────────────────
Remaining → conversation history (oldest turns dropped first)
```

When context fill reaches 80%, the oldest conversation turns are automatically pushed to the vector DB so they remain searchable via `"what did I say about X earlier"`.

---

## Troubleshooting

**Brain won't initialise:**
Check the Error Console (`Ctrl+E`). Common causes:
- GPU VRAM < 4GB (need at least 4GB for 4-bit Phi-3)
- Model path wrong in `cyborg_assistant.py` → update `MODEL_PATH`
- CUDA not available → check `torch.cuda.is_available()`

**No audio/video transcription:**
```bash
pip install faster-whisper
# Also install ffmpeg and add to PATH:
# https://ffmpeg.org/download.html
```

**Network scan finds no devices:**
- Ensure all devices are on the same subnet
- Windows Firewall may block ping — temporarily disable or allow ICMP
- Try `arp -a` in Command Prompt to verify ARP table is populated

**SMB browse shows no shares:**
- Enable File and Printer Sharing on the remote device
- Check: Control Panel → Network → Advanced Sharing Settings → Turn on file sharing
- Ensure both machines are in the same Workgroup

**`SentenceTransformer` error:**
Do not pass `local_files_only=True` to `SentenceTransformer()`. It accepts the local path directly. Only `AutoTokenizer` and `AutoModelForCausalLM` use that argument.

---

## Dependencies Summary

```
Core AI:
  torch                  GPU inference
  transformers           Phi-3 model loading
  bitsandbytes           4-bit quantization
  accelerate             device_map="auto"
  sentence-transformers  all-MiniLM-L6-v2 embeddings
  qdrant-client          vector database

UI:
  PyQt6                  desktop GUI framework

Document processing:
  pypdf                  PDF text extraction (tier 1)
  pymupdf (fitz)         PDF structure extraction (tier 0)
  pdfplumber             PDF tables (tier 2 fallback)
  python-docx            DOCX extraction
  python-pptx            PPTX extraction
  openpyxl               XLSX extraction

Media:
  faster-whisper         Audio/video transcription (recommended)
  openai-whisper         Fallback transcription
  ffmpeg                 Video audio extraction (external binary)

Optional:
  Pillow                 Image processing
  pytesseract            Image OCR
  tesseract              OCR engine (external binary)
```

---

## Architecture Diagram

```
                        CYBORG SYSTEM
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  INPUT SOURCES                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │  Local   │ │ Network  │ │  Audio/  │ │  Code/Text/  │  │
│  │  Docs    │ │  Share   │ │  Video   │ │  Notebooks   │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬───────┘  │
│       │            │            │               │           │
│       └────────────┴────────────┴───────────────┘           │
│                              │                              │
│                    INGEST PIPELINE                           │
│              ┌───────────────▼──────────────┐               │
│              │  1. SHA-256 dedup check      │               │
│              │  2. Content extraction       │               │
│              │  3. Description generation   │               │
│              │  4. Semantic chunking        │               │
│              │  5. Embedding (GPU)          │               │
│              └───────────────┬──────────────┘               │
│                              │                              │
│              ┌───────────────▼──────────────┐               │
│              │         STORAGE              │               │
│              │  Qdrant (vectors, on-disk)   │               │
│              │  BM25 (keywords, on-disk)    │               │
│              │  Hash registry (dedup)       │               │
│              └───────────────┬──────────────┘               │
│                              │                              │
│                         QUERY TIME                          │
│              ┌───────────────▼──────────────┐               │
│              │    HYBRID RETRIEVAL          │               │
│              │  Vector search (semantic)    │               │
│              │  BM25 search (keywords)      │               │
│              │  Score fusion + rerank       │               │
│              │  Timestamp extraction        │               │
│              └───────────────┬──────────────┘               │
│                              │                              │
│              ┌───────────────▼──────────────┐               │
│              │   Phi-3 GENERATION           │               │
│              │  Context: persona +          │               │
│              │  retrieved chunks +          │               │
│              │  chat history                │               │
│              │  Streaming → UI              │               │
│              └──────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```
#   C y b o r g A I  
 #   C y b o r g A I  
 