import asyncio
import structlog
from pathlib import Path
from typing import Optional
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from config.settings import settings
from services.vault_service import VaultService
from services.voice_service import VoiceService

log = structlog.get_logger(__name__)


class InboxWatcher(FileSystemEventHandler):
    def __init__(self, service: 'IngestionService'):
        self.service = service

    def on_created(self, event):
        if event.is_directory:
            return
        log.info(f"New file in Inbox: {event.src_path}")
        asyncio.run_coroutine_threadsafe(
            self.service.process_file(event.src_path),
            self.service.loop
        )


class IngestionService:
    """
    Multimodal Ingestion Pipeline.
    Monitors Inbox/ and processes images, video, audio, and documents.
    """
    def __init__(self, vault_service: VaultService, voice_service: VoiceService, graph_service: 'GraphService', llm_service: 'LLMService'):
        self.vault_service = vault_service
        self.voice_service = voice_service
        self.graph_service = graph_service
        self.llm_svc = llm_service
        self.inbox_root = settings.brain_dir / "Inbox"
        self._is_running = False
        self._observer: Optional[Observer] = None
        self.loop = asyncio.get_event_loop()

    async def initialize(self):
        if self._is_running:
            return

        # Ensure subdirs exist
        for d in ["images", "videos", "audio", "documents"]:
            (self.inbox_root / d).mkdir(parents=True, exist_ok=True)

        self._is_running = True
        self._observer = Observer()
        self._observer.schedule(InboxWatcher(self), str(self.inbox_root), recursive=True)
        self._observer.start()
        log.info("Ingestion Service (Inbox Watcher) started", root=str(self.inbox_root))

    async def process_file(self, file_path: str):
        path = Path(file_path)
        if path.suffix.lower() == ".md":
            return  # Skip markdown

        log.info(f"Processing ingestion for {path.name}...")

        ext = path.suffix.lower()
        content = ""
        metadata = {}

        try:
            if ext in [".png", ".jpg", ".jpeg", ".webp"]:
                content = await self._process_image(path)
                metadata["type"] = "image"
            elif ext in [".mp4", ".mov", ".mkv", ".webm"]:
                content = await self._process_video(path)
                metadata["type"] = "video"
            elif ext in [".mp3", ".wav", ".m4a", ".ogg"]:
                content = await self._process_audio(path)
                metadata["type"] = "audio"
            elif ext in [".pdf", ".docx", ".pptx", ".txt"]:
                content = await self._process_document(path)
                metadata["type"] = "document"
            else:
                log.warning(f"Unsupported file type for ingestion: {ext}")
                return

            if content:
                # 1. Categorize via LLM for AI OS Structure
                cat_prompt = f"""Categorize the following content into the AI OS ACE structure.
                ACE Structure:
                - Atlas/Concepts: Permanent knowledge, technical concepts, theoretical framework.
                - Atlas/People: Contact info, bios, social relationships.
                - Atlas/Resources: Generic references, papers, documentations.
                - Calendar: Time-based logs, journals, dates.
                - Efforts/Projects: Specific active project names (e.g. Project_Alpha).
                - AI_OS/Skills: Process documentation, AI workflow instructions.

                Content Snippet: {content[:1000]}
                
                Return ONLY the folder path (e.g. ACE/Atlas/Concepts) and a suggested note title.
                Format: FOLDER: <path> | TITLE: <title>
                """
                cat_res = await self.llm_svc.generate(cat_prompt)
                
                folder_path = "ACE/Atlas/Resources" # Default
                note_title = f"Ingested {path.stem}"
                
                if "FOLDER:" in cat_res and "TITLE:" in cat_res:
                    try:
                        folder_path = cat_res.split("FOLDER:")[1].split("|")[0].strip()
                        note_title = cat_res.split("TITLE:")[1].strip()
                    except:
                        pass

                tags = ["ingested", metadata["type"]]
                
                # Create corresponding markdown note
                note = await self.vault_service.create_note(
                    title=note_title,
                    content=f"## Extracted Content from [[{path.name}]]\n\n{content}",
                    folder=folder_path,
                    tags=tags,
                    note_type="ingestion"
                )
                
                # 2. Update AI OS Indexing
                await self.vault_service.register_note_in_index(note["id"])
                log.info(f"AI OS Ingestion complete: categorized to {folder_path}")

                # 3. Add to Knowledge Graph for RAG availability
                try:
                    note_path = self.vault_service.vault_root / note["path"]
                    await self.graph_service._ingest_single_file(note_path)
                    log.info(f"Graph ingestion complete for note {note['id']}")
                except Exception as ge:
                    log.error(f"Graph ingestion failed for {note['id']}: {ge}")

                # 4. Universal Content Indexing (BM25 + Semantic)
                try:
                    from services.cyborg_content_index import ContentIndex
                    if not hasattr(self, '_content_index'):
                        self._content_index = ContentIndex()
                    # index the original file
                    chunks_indexed = self._content_index.index_file(str(path.absolute()))
                    log.info(f"Content index (BM25) ingestion complete: {chunks_indexed} chunks indexed.")
                except Exception as e:
                    log.error(f"Content index ingestion failed: {e}")

        except Exception as e:
            log.error(f"Ingestion failed for {path.name}: {e}")

    async def _process_image(self, path: Path) -> str:
        log.info(f"Running OCR on image: {path.name}")
        from services.utils.text_extractor import extract_text
        result = await extract_text(path)
        return result if result else f"[Image OCR: no text detected in {path.name}]"

    async def _process_audio(self, path: Path) -> str:
        # Use existing VoiceService (Whisper)
        if not self.voice_service.is_ready:
            return "Voice service not ready for transcription."

        # Whisper usually takes ndarray, but we can load from file
        import librosa
        audio, sr = librosa.load(str(path), sr=16000)
        transcript = self.voice_service.transcribe(audio)
        return transcript

    async def _process_video(self, path: Path) -> str:
        log.info(f"Video processing (audio extraction) for {path.name}")
        if not self.voice_service.is_ready:
            return "Voice service not ready for transcription."

        import tempfile
        import subprocess
        import librosa

        try:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_audio:
                tmp_path = tmp_audio.name

            # Extract audio using ffmpeg
            subprocess.run([
                "ffmpeg", "-y", "-i", str(path), "-vn", "-acodec", "pcm_s16le",
                "-ar", "16000", "-ac", "1", tmp_path
            ], capture_output=True, check=True)

            audio, sr = librosa.load(tmp_path, sr=16000)
            transcript = self.voice_service.transcribe(audio)

            import os
            os.unlink(tmp_path)

            return f"Video Transcript:\n{transcript}"
        except Exception as e:
            log.error(f"Video transcription failed: {e}")
            return f"[Video Transcription Failed: {str(e)}]"

    async def _process_document(self, path: Path) -> str:
        from services.utils.text_extractor import extract_text
        result = await extract_text(path)
        return result if result else f"[Could not extract text from {path.name}]"

    async def cleanup(self):
        self._is_running = False
        if self._observer:
            self._observer.stop()
            self._observer.join()
