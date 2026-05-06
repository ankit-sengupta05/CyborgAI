# 📋 Product Requirements Document (PRD)
## AI OS: Local-First Multimodal Markdown File Management System

**Document Version:** 1.0  
**Target Platform:** Flutter (Android + Windows)  
**Language:** Dart (100%)  
**Execution:** Fully Local / Offline-First  
**Generated For:** Claude Project Generation  

---

## 🎯 Executive Summary

Build a **local-first, privacy-preserving AI OS** that replicates the "File Over AI" philosophy from Nick Milo's AI OS system [[video transcript]] and incorporates multimodal knowledge graph features from the Graphify project [[GitHub: graphify]]. The app enables users to manage `.md` files with Obsidian-like graph visualization, ingest multimodal content (images, video, audio, docx, pptx, txt), extract deep semantic content using TroCR and local models, and query knowledge via local GGUF LLMs—all running entirely on-device in Dart/Flutter.

> **Core Philosophy:** "File Over AI" — Your data stays as plain text `.md` files in folders. No cloud lock-in. Any AI tool can read your vault. [[video transcript]]

---

## 🧭 Core Principles

| Principle | Implementation |
|-----------|---------------|
| **Local-First** | All processing, storage, and inference happens on-device. No mandatory cloud dependencies. |
| **File-Based** | Knowledge stored as plain `.md` files in ACE folder structure (Atlas/Calendar/Efforts). [[video transcript]] |
| **Portable Identity** | `me.md` file contains user preferences, thinking style, and AI interaction guidelines. [[video transcript]] |
| **Graph-Native** | Knowledge represented as nodes/edges with Obsidian-style interactive graph view. [[graphify]] |
| **Multimodal Ingestion** | Support images, video, audio, PDF, docx, pptx, txt with deep extraction via TroCR + Whisper. |
| **Local LLM** | GGUF model support with path-based loading via `llama.cpp` Dart FFI bindings. [[79]][[86]] |
| **Performance** | Isolates for heavy computation, chunked file loading, SHA256 caching for incremental updates. [[95]][[graphify]] |

---

## 🗂️ Folder Structure (ACE + AI OS)

```
vault_root/
├── .ai_os/                          # App configuration & cache
│   ├── config.json                  # User settings, LLM path, TroCR model path
│   ├── graph_cache/                 # Serialized graph state (JSON)
│   ├── embeddings_cache/            # Optional: local vector cache
│   └── ingestion_queue/             # Pending file processing jobs
│
├── ACE/                             # Core Knowledge Structure [[video transcript]]
│   ├── Atlas/                       # Permanent knowledge (concepts, references)
│   │   ├── Concepts/
│   │   ├── People/
│   │   ├── Resources/
│   │   └── _index.md                # Atlas map of content
│   │
│   ├── Calendar/                    # Time-based notes
│   │   ├── 2026/
│   │   │   ├── 04-April/
│   │   │   │   ├── 2026-04-29.md
│   │   │   │   └── _index.md
│   │   │   └── _index.md
│   │   └── _index.md
│   │
│   └── Efforts/                     # Active projects & tasks
│       ├── Project_Alpha/
│       │   ├── brief.md
│       │   ├── tasks.md
│       │   └── _index.md
│       └── _index.md
│
├── AI_OS/                           # AI OS Maps Layer [[video transcript]]
│   ├── me.md                        # Portable identity: who I am, how I think
│   ├── vault_map.md                 # Navigation manual: folder structure, note types
│   ├── skills/                      # Process documentation (email, research, etc.)
│   │   ├── daily_briefing.md
│   │   ├── email_drafting.md
│   │   └── _index.md
│   └── _index.md
│
├── Inbox/                           # Raw ingestion staging area
│   ├── images/
│   ├── videos/
│   ├── audio/
│   ├── documents/
│   └── _process_queue.md
│
├── Archive/                         # Deprecated/old content
│   └── _index.md
│
└── _graphify_ignore                 # Exclude patterns (like .gitignore) [[graphify]]
```

---

## 🧩 Feature Specifications

### 1. 🗄️ Markdown File Management System

| Feature | Description | Technical Implementation |
|---------|-------------|-------------------------|
| **File Explorer** | Tree view of vault folders with `.md` preview | `file_picker` + `path_provider` + custom `FileTreeWidget` |
| **Editor** | Rich markdown editor with live preview, backlinks, wikilinks | `flutter_markdown` + custom `LinkParser` + `BacklinkResolver` |
| **Frontmatter** | YAML frontmatter support for metadata, tags, aliases | `yaml` package parser + `NoteMetadata` model |
| **Search** | Full-text search across vault with fuzzy matching | `sqlite3` FTS5 virtual table + `fuzzy_search` algorithm |
| **Sync Watcher** | Auto-reload on file changes (local only) | `watcher` package + `StreamBuilder` for reactive updates |

### 2. 🕸️ Obsidian-Style Graph View

| Feature | Description | Technical Implementation |
|---------|-------------|-------------------------|
| **Interactive Graph** | Force-directed graph with zoom, pan, node selection | `graphview` package [[15]] + custom `SpringPhysics` simulation [[20]] |
| **Node Types** | Visual distinction: note, file, tag, concept, entity | `CustomNodePainter` with color/shape coding |
| **Edge Types** | `LINKED_TO`, `REFERENCED_BY`, `SEMANTIC_SIMILAR`, `INFERRED` | `GraphEdge` enum + confidence score (0.0-1.0) [[graphify]] |
| **Community Detection** | Auto-cluster related notes using Leiden algorithm | Port `graspologic` Leiden to Dart or use `networkx` via FFI |
| **Filtering** | Filter by tag, date, folder, edge type, confidence | Reactive `FilterController` + `ValueNotifier` graph rebuild |
| **Export** | Export graph as JSON, GraphML, SVG, or Obsidian-compatible | `graph_export_service.dart` with multiple serializers |

### 3. 🔄 Multimodal File Ingestion Pipeline

```
┌─────────────────────────────────────────┐
│  INGESTION MANAGER (Isolate-Based)      │
├─────────────────────────────────────────┤
│ 1. File Detection & Type Routing        │
│    • images: .png, .jpg, .webp, .gif    │
│    • video: .mp4, .mov, .mkv, .webm     │
│    • audio: .mp3, .wav, .m4a, .ogg      │
│    • docs: .pdf, .docx, .pptx, .txt     │
│                                         │
│ 2. Format-Specific Extractors           │
│    ├─ Images → TroCR (handwritten/text) │
│    ├─ Video → Whisper (audio) + TroCR   │
│    │          (keyframe OCR)            │
│    ├─ Audio → Whisper (local)           │
│    ├─ PDF → pdfx + TroCR fallback       │
│    ├─ DOCX/PPTX → open_xml parser [[44]]│
│    └─ TXT → direct UTF-8 read           │
│                                         │
│ 3. Semantic Enrichment                  │
│    • Local LLM (GGUF) for concept       │
│      extraction & relationship inference│
│    • Tag generation, entity recognition │
│                                         │
│ 4. Markdown Conversion & Linking        │
│    • Generate .md with frontmatter      │
│    • Auto-backlinks to related notes    │
│    • Add to graph with EXTRACTED edges  │
│                                         │
│ 5. Cache & Incremental Update           │
│    • SHA256 hash tracking [[graphify]]  │
│    • Skip re-processing unchanged files │
└─────────────────────────────────────────┘
```

#### TroCR Integration Strategy
- **Model**: Use `microsoft/trocr-base-handwritten` or `trocr-large-printed` via ONNX Runtime [[38]]
- **Dart Binding**: Wrap TroCR Python via `flutter_python` FFI or port inference to Dart using `onnxruntime_dart`
- **Fallback**: If TroCR unavailable, use `google_mlkit_text_recognition` [[34]] or `tesseract_ocr` [[36]]
- **Performance**: Run OCR in background isolate; stream results to UI

#### Whisper Integration for Audio/Video
- Use `whisper_ggml_plus` [[54]] or `whisper_kit` [[56]] for on-device transcription
- Support quantized models (tiny, base, small) for mobile performance
- Cache transcripts in `graph_cache/transcripts/` with SHA256 key [[graphify]]

#### Office Document Parsing
- Use `open_xml` [[48]] or `flutter_pptx` [[44]] for native Dart OOXML parsing
- Extract text, headings, metadata, comments
- Convert to markdown with preserved structure

### 4. 🤖 Local LLM Integration (GGUF)

| Requirement | Implementation |
|-------------|---------------|
| **Model Loading** | Path picker UI → validate `.gguf` file → load via `llamadart` [[79]] or `llama_cpp_dart` [[80]] |
| **Inference API** | `LocalLLMService` class with `streamCompletion(String prompt)` method |
| **Context Management** | Sliding window + summarization for long vault queries |
| **Prompt Templates** | Pre-built templates for: `summarize_note`, `extract_concepts`, `generate_backlinks`, `answer_query` |
| **Hardware Optimization** | Detect CPU/GPU; enable Metal (macOS), Vulkan (Windows), NNAPI (Android) via llama.cpp flags |
| **Memory Safety** | Load models in dedicated isolate; use `compute()` for heavy inference [[95]] |

```dart
// Example: LLM Service Interface
abstract class LocalLLMService {
  Future<void> loadModel({required String ggufPath, int nGpuLayers = 20});
  Stream<String> streamCompletion(String prompt, {LLMConfig config});
  Future<ExtractionResult> extractConcepts(String content, {String notePath});
  Future<List<Relationship>> inferRelationships(Note a, Note b);
  void unloadModel();
}
```

### 5. 🔐 Privacy & Security

- **Zero Telemetry**: No analytics, no crash reporting, no network calls by default
- **Data Ownership**: All files remain in user-controlled folders; app never copies/moves without permission
- **Encryption Option**: Optional AES-256 encryption for vault folder (user-provided key)
- **Permission Model**: Granular Android storage permissions; Windows UAC prompts for system folders
- **AI Boundary**: Clearly mark AI-generated content with `#ai-assisted` tag or emoji [[video transcript]]

---

## 🏗️ Technical Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────┐
│              FLUTTER UI LAYER               │
├─────────────────────────────────────────────┤
│ • FileExplorerWidget   • GraphViewWidget    │
│ • MarkdownEditor       • IngestionDashboard │
│ • SettingsPanel        • LLMControlPanel    │
└────────────┬────────────────┬──────────────┘
             │                │
┌────────────▼────┐  ┌───────▼────────────┐
│  BUSINESS LOGIC │  │  STATE MANAGEMENT  │
│  (BLoC/Riverpod)│  │  (Riverpod/Provider)│
├─────────────────┤  ├────────────────────┤
│ • FileService   │  │ • VaultState       │
│ • GraphService  │  │ • GraphState       │
│ • IngestionService│ • LLMState          │
│ • LLMService    │  │ • UIState          │
│ • CacheService  │  │ • FilterState      │
└──────┬──────────┘  └────────┬───────────┘
       │                      │
┌──────▼──────────────────────▼──────────┐
│         CORE SERVICES (Isolates)        │
├────────────────────────────────────────┤
│ • FileWatcherIsolate  • OCRIsolate     │
│ • WhisperIsolate      • LLMIsolate     │
│ • GraphBuilderIsolate • SearchIsolate  │
│ • SHA256CacheIsolate                   │
└──────┬────────────────┬────────────────┘
       │                │
┌──────▼────┐  ┌───────▼────────┐
│ NATIVE FFI│  │ DART PACKAGES  │
│ BINDINGS  │  │ (pub.dev)      │
├───────────┤  ├────────────────┤
│ • llama.cpp│  • file_picker   │
│ • onnxruntime│ • path_provider│
│ • whisper.cpp│ • sqlite3      │
│ • libtrocr  │ • graphview    │
│ • libopenxml│ • open_xml     │
└───────────┘  └────────────────┘
```

### Key Dart Packages

```yaml
dependencies:
  # Core Flutter
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  
  # File & Storage
  file_picker: ^6.1.1
  path_provider: ^2.1.2
  watcher: ^1.1.0
  cross_file: ^0.3.3+7
  
  # Markdown & Text
  flutter_markdown: ^0.6.19
  yaml: ^3.1.2
  markdown: ^7.2.1
  
  # Graph Visualization
  graphview: ^0.7.0  # or advanced_graphview [[21]]
  vector_math: ^2.1.4
  
  # Database & Search
  sqlite3: ^2.4.0
  drift: ^2.15.0  # for FTS5 full-text search
  
  # Multimodal Processing
  open_xml: ^0.2.0  # DOCX/PPTX parsing [[48]]
  pdfx: ^2.3.0      # PDF text extraction
  image: ^4.1.7     # Image preprocessing for OCR
  
  # Local LLM
  llamadart: ^0.2.0  # or llama_cpp_dart [[79]][[80]]
  gguf: ^0.1.0       # GGUF metadata parsing [[86]]
  
  # Audio/Video
  whisper_ggml_plus: ^0.1.0  # or whisper_kit [[54]][[56]]
  just_audio: ^0.9.36        # Audio playback
  
  # Utilities
  collection: ^1.18.0
  crypto: ^3.0.3  # SHA256 hashing
  isolate: ^2.1.1
  ffi: ^2.1.0
  
dev_dependencies:
  build_runner: ^2.4.8
  riverpod_generator: ^2.3.9
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

### Platform-Specific Considerations

| Platform | File Access | LLM Performance | Notes |
|----------|------------|-----------------|-------|
| **Android** | Scoped Storage API; request `MANAGE_EXTERNAL_STORAGE` for vault access | Use quantized GGUF (Q4_K_M); limit `n_ctx` to 2048 for RAM-constrained devices | Test on Android 10+; handle background processing limits |
| **Windows** | Direct `dart:io` file access; UAC prompts for Program Files | Full GPU acceleration via Vulkan/DirectML; support larger models (7B+) | Package as MSIX; support Windows 10+ |
| **Cross-Platform** | Use `path_provider` for app data; let user choose vault location | Abstract hardware detection; fallback to CPU-only mode | All heavy computation in isolates to avoid UI jank |

---

## 📊 Performance & Scalability Requirements

| Metric | Target | Strategy |
|--------|--------|----------|
| **App Launch** | < 2s cold start | Lazy-load services; defer graph build |
| **File Open** | < 500ms for 10KB .md | Stream parsing; cache rendered markdown |
| **Graph Render** | < 1s for 500 nodes | Virtualize nodes; level-of-detail rendering |
| **OCR (Image)** | < 5s for 1080p image | Run in isolate; show progress; cache results |
| **Transcription** | < 30s for 5min audio (base model) | Use tiny/base models on mobile; allow user model selection |
| **LLM Inference** | < 10 tokens/sec (7B Q4 on mid-tier device) | Stream output; allow early stop; quantization |
| **Memory Usage** | < 500MB typical; < 2GB peak | Chunk large files; unload models when idle; isolate memory boundaries |
| **Storage** | Efficient caching; user-controlled retention | SHA256 deduplication [[graphify]]; configurable cache size |

### Scalability Patterns
- **Incremental Graph Updates**: Only re-process changed files using SHA256 cache [[graphify]]
- **Lazy Loading**: Load graph nodes/edges on-demand as user navigates
- **Background Processing**: All ingestion/OCR/LLM tasks run in isolates with progress callbacks
- **Configurable Quality**: Let users trade speed vs accuracy (e.g., TroCR model size, Whisper model, LLM context length)

---

## 🎨 UI/UX Requirements

### Core Screens
1. **Vault Browser**: Tree view + search + quick actions (new note, import file)
2. **Note Editor**: Split view (edit/preview), backlink panel, tag manager
3. **Graph View**: Interactive force-directed graph with filter panel, node inspector
4. **Ingestion Dashboard**: Queue status, progress bars, error logs, retry controls
5. **Settings**: LLM model path, TroCR/Whisper model selection, privacy toggles, performance profiles

### Design System
- **Theme**: Light/dark mode; follow Material 3 with Obsidian-inspired accents
- **Typography**: Monospace for code blocks; readable sans-serif for body
- **Icons**: Consistent icon set for file types, edge types, AI actions
- **Accessibility**: Screen reader support, dynamic text sizing, high-contrast mode

### Key Interactions
- **Drag & Drop**: Drop files into Inbox → auto-ingest with progress feedback
- **Right-Click Context**: File actions (open, edit, graph-link, reprocess)
- **Graph Navigation**: Click node → open note; drag to create manual link; hover for preview
- **LLM Chat Panel**: Slide-in panel for querying vault with local LLM (optional)

---

## 🔧 Development & Testing Strategy

### Project Structure
```
lib/
├── main.dart
├── app/
│   ├── app.dart                 # Root widget with Riverpod scope
│   └── router.dart              # GoRouter configuration
├── features/
│   ├── file_manager/
│   │   ├── widgets/
│   │   ├── logic/
│   │   └── models/
│   ├── graph_view/
│   ├── ingestion/
│   ├── llm/
│   └── settings/
├── core/
│   ├── services/                # FileService, GraphService, etc.
│   ├── isolates/                # Background task definitions
│   ├── utils/                   # SHA256, path helpers, etc.
│   └── models/                  # Note, GraphNode, Edge, etc.
├── data/
│   ├── repositories/
│   ├── datasources/             # Local file, SQLite, cache
│   └── mappers/
└── gen/                         # Generated code (Riverpod, etc.)
```

### Testing Pyramid
```
Unit Tests (70%)
├─ Note parsing, frontmatter, link resolution
├─ Graph algorithms (clustering, pathfinding)
├─ Cache logic (SHA256, invalidation)
└─ LLM prompt templating

Integration Tests (20%)
├─ File ingestion pipeline (mock OCR/Whisper)
├─ Graph view + editor synchronization
├─ Settings persistence + reload

E2E Tests (10%)
├─ Full ingestion flow: image → OCR → .md → graph
├─ LLM query: prompt → stream response → UI update
├─ Cross-platform file access scenarios
```

### CI/CD
- **GitHub Actions**: Test on Ubuntu, Windows, Android emulator
- **Build Artifacts**: APK (Android), MSIX (Windows), debug symbols
- **Release Checklist**: Model path validation, permission prompts, offline mode verification

---

## 🚀 MVP Scope vs. Future Enhancements

### MVP (v1.0) - "Local Knowledge Base"
- ✅ ACE folder structure + `.md` file management
- ✅ Basic graph view (force-directed, clickable nodes)
- ✅ Image ingestion with TroCR fallback (ML Kit)
- ✅ Text/DOCX/PPTX parsing via `open_xml`
- ✅ Local LLM loading (GGUF) + simple completion streaming
- ✅ SHA256 caching for incremental updates
- ✅ Android + Windows builds

### v1.1 - "Multimodal Depth"
- 🔄 Full TroCR ONNX integration for handwritten text
- 🔄 Whisper.cpp integration for audio/video transcription
- 🔄 Semantic relationship inference via local LLM
- 🔄 Community detection (Leiden algorithm port)

### v1.2 - "Collaboration & Sync"
- 🔄 Optional encrypted vault sync (user-controlled cloud)
- 🔄 Multi-vault support with cross-repo graph merging [[graphify]]
- 🔄 Plugin system for custom extractors/LLM prompts

### Future Vision
- 🌐 "Ideaverse Network": Connect multiple local vaults with privacy-preserving graph queries
- 🤖 On-device fine-tuning: Adapt LLM to user's writing style over time
- 🧠 Memory-augmented inference: Persistent vector cache for faster semantic search

---

## ⚠️ Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **TroCR Dart port complexity** | High | Start with ML Kit fallback; provide Python bridge option via `flutter_python` |
| **LLM performance on mobile** | High | Default to tiny/base models; clear UI warnings for large models; allow remote inference opt-in |
| **Windows file permission UX** | Medium | Use `file_picker` with clear guidance; document manual vault setup |
| **Graph rendering performance** | Medium | Virtualize nodes; implement LOD; allow user to limit visible nodes |
| **Storage bloat from caches** | Medium | Configurable cache limits; auto-cleanup of old SHA256 entries |
| **Cross-platform FFI compatibility** | Medium | Isolate native bindings behind service interfaces; provide mock implementations for testing |

---

## ✅ Acceptance Criteria

1. **File Management**
   - [ ] User can create, edit, delete `.md` files in ACE structure
   - [ ] Wikilinks `[[Note Name]]` auto-create backlinks
   - [ ] Full-text search returns results in < 1s for 1000-note vault

2. **Graph View**
   - [ ] Interactive force-directed graph renders 200 nodes at 30 FPS
   - [ ] Clicking node opens corresponding note in editor
   - [ ] Filter panel supports tag, date, folder, edge-type filters

3. **Multimodal Ingestion**
   - [ ] Dropping image into Inbox triggers OCR → generates `.md` with extracted text
   - [ ] DOCX/PPTX files parsed to markdown with preserved headings/lists
   - [ ] Audio file transcription completes with progress indicator

4. **Local LLM**
   - [ ] User can select `.gguf` file via path picker
   - [ ] Model loads successfully; inference streams tokens to UI
   - [ ] "Summarize this note" prompt returns coherent output

5. **Performance & Privacy**
   - [ ] App launches in < 2s on mid-tier Android device
   - [ ] No network calls made without explicit user opt-in
   - [ ] All user data remains in user-specified vault folder

---

## 📦 Deliverables for Claude Project Generation

1. **Complete Flutter project scaffold** with folder structure above
2. **Riverpod state management** setup for all features
3. **Isolate templates** for OCR, Whisper, LLM, graph building
4. **Service interfaces** with mock implementations for testing
5. **UI components** for file tree, graph view, editor, ingestion dashboard
6. **Platform channel stubs** for native FFI (llama.cpp, ONNX, etc.)
7. **Sample `me.md` and `vault_map.md`** templates per AI OS philosophy
8. **Documentation**: `ARCHITECTURE.md`, `CONTRIBUTING.md`, platform setup guides

---

> **Final Note to Claude**: This PRD prioritizes **local-first, privacy-preserving architecture** with **Dart-native implementation** wherever possible. When native bindings are required (llama.cpp, TroCR, Whisper), isolate them behind clean service interfaces with mock implementations for testing. Favor incremental progress: ship MVP with fallbacks (ML Kit OCR, tiny LLM models), then enhance with full TroCR/Whisper integration. Always keep the user's `.md` files as the single source of truth—this app is a *lens* on their knowledge, not a walled garden.

*Generated for local execution on Android + Windows. All processing stays on-device. Your vault, your rules.* 🗝️