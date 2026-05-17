import os

# Apply Windows-specific patches (Encoding, Stability)
if os.name == 'nt':
    try:
        from patch_windows import apply_patches
        apply_patches()
    except Exception:
        pass

import asyncio
from config.settings import settings
import collections
import queue
import threading
import time
from typing import Optional

import numpy as np

# ============================================================
# PATCH: numpy.load — Allow pickle for Kokoro voices.bin
# ============================================================
_orig_np_load = np.load

def _patched_np_load(*args, **kwargs):
    kwargs["allow_pickle"] = True
    return _orig_np_load(*args, **kwargs)

np.load = _patched_np_load

import sounddevice as sd
import structlog
from faster_whisper import WhisperModel
from kokoro_onnx import Kokoro
import webrtcvad
import torch
from pathlib import Path

# ============================================================
# PACING CONSTANTS (from jarvis.py)
# ============================================================
FIRST_CHUNK_CHARS = 80
SUBSEQUENT_CHUNK_CHARS = 160
FINAL_SILENCE_S = 0.50
KOKORO_SR = 24000
_DRAIN = object()  # Jarvis-style EOS sentinel

# ============================================================
# PATCH: torch.load — PyTorch 2.6 fix
# ============================================================
_orig_torch_load = torch.load


def _patched_torch_load(f, map_location=None, pickle_module=None, **kwargs):
    kwargs["weights_only"] = False
    if pickle_module is not None:
        return _orig_torch_load(f, map_location=map_location, pickle_module=pickle_module, **kwargs)
    return _orig_torch_load(f, map_location=map_location, **kwargs)


torch.load = _patched_torch_load



log = structlog.get_logger(__name__)

VOICES_CATALOGUE = {
    "1": ("af_sarah", "American Female – Sarah (conversational)"),
    "2": ("af_bella", "American Female – Bella (bright, clear)"),
    "3": ("af_nicole", "American Female – Nicole (soft, gentle)"),
    "4": ("af_sky", "American Female – Sky (airy)"),
    "5": ("af", "American Female – Default"),
    "6": ("am_adam", "American Male – Adam (deep, clear)"),
    "7": ("am_michael", "American Male – Michael (balanced)"),
    "8": ("bf_emma", "British Female – Emma (crisp)"),
    "9": ("bf_isabella", "British Female – Isabella (elegant)"),
    "10": ("bm_george", "British Male – George (classic)"),
    "11": ("bm_lewis", "British Male – Lewis (warm)"),
}


class VoiceService:
    """
    Service for Speech-to-Text (Whisper), Text-to-Speech (Kokoro),
    and Voice Activity Detection (VAD).
    """

    def __init__(self):
        self._kokoro: Optional[Kokoro] = None
        self._whisper: Optional[WhisperModel] = None
        self._vad: Optional[webrtcvad.Vad] = None

        self._initialized = False
        self._stop_ev = threading.Event()
        self._play_q = queue.Queue()
        self._synth_q = queue.Queue()
        self._audio_thread_handle: Optional[threading.Thread] = None
        self._synth_thread_handle: Optional[threading.Thread] = None
        self._wake_thread_handle: Optional[threading.Thread] = None

        # Buffering state for streaming TTS
        self._current_buffer = ""
        self._is_first_chunk = True

        # Wake word state
        self._wake_callback = None
        self._is_listening_for_wake = False

        # Constants from settings
        self.kokoro_sr = 24000
        self.device_sr = settings.device_sr
        self.vad_sr = settings.vad_sr
        self.vad_frame_ms = settings.vad_frame_ms
        self.vad_silence_frames = settings.vad_silence_frames
        self.vad_speech_frames = settings.vad_speech_frames
        self.max_record_s = settings.max_record_s

        # Flush settings
        self.first_chunk_chars = 80
        self.subsequent_chunk_chars = 160
        self._lock = threading.Lock()
        self._interrupt_playback = False  # Flag to break long audio writes

    @property
    def is_ready(self) -> bool:
        return self._initialized

    async def initialize(self):
        """Load models and start worker threads."""
        if self._initialized:
            return

        # Load models (this will now block startup until ready)
        await self._load_models_task()

        # Start worker threads (Audio & Synthesis)
        log.info("[VOICE] Starting worker threads...")
        self._start_workers()

    async def _load_models_task(self):
        try:
            # 1. TTS - Kokoro
            m_path = settings.base_dir / settings.kokoro_model_path
            v_path = settings.base_dir / settings.kokoro_voices_path

            if m_path.exists() and v_path.exists():
                try:
                    self._kokoro = await asyncio.to_thread(Kokoro, str(m_path), str(v_path))
                    log.info("[OK] Kokoro TTS loaded", device="cpu (onnx)", voices_path=str(v_path))
                except Exception as ke:
                    import traceback
                    log.error(
                        "[VOICE] Kokoro load failed",
                        error=str(ke), traceback=traceback.format_exc()
                    )
            else:
                log.error(
                    "[VOICE] Kokoro files missing!",
                    m_path=str(m_path), v_path=str(v_path)
                )

            # 2. STT - Whisper
            stt_dir = settings.models_dir / "stt"
            stt_dir.mkdir(parents=True, exist_ok=True)

            # Check for local backup
            _stt_backup_path = (
                r"C:\Users\ankit\Projects\Python Projects\langchain\models"
                r"\voice_models\speech_to_text\models--Systran--"
                r"faster-whisper-small"
            )
            backup_stt = Path(_stt_backup_path)
            if (backup_stt.exists() and not
                    (stt_dir / "models--Systran--faster-whisper-small").exists()):
                log.info("[VOICE] Copying Whisper backup...")
                import shutil
                shutil.copytree(
                    str(backup_stt),
                    str(stt_dir / "models--Systran--faster-whisper-small"),
                    dirs_exist_ok=True
                )

            try:
                log.info("[VOICE] Loading Whisper model...", size=settings.whisper_model_size)
                # Use a timeout for Whisper loading to prevent hanging the entire service
                import concurrent.futures
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    future = executor.submit(
                        WhisperModel,
                        settings.whisper_model_size,
                        device="cpu",
                        compute_type="int8",
                        download_root=str(stt_dir),
                        local_files_only=True
                    )
                    try:
                        self._whisper = future.result(timeout=45)  # 45s timeout
                        log.info("[OK] Whisper STT loaded")
                    except concurrent.futures.TimeoutError:
                        log.error(
                            "[VOICE] Whisper load timed out (45s). "
                            "STT will be disabled."
                        )
                    except Exception as we:
                        log.error(f"[VOICE] Whisper load failed: {we}. STT will be disabled.")
            except Exception as e:
                log.error("[VOICE] Whisper setup failed", error=str(e))

            # 3. VAD
            self._vad = webrtcvad.Vad(settings.vad_aggressiveness)
            log.info("[OK] VAD loaded", aggressiveness=settings.vad_aggressiveness)

            # Final device check
            try:
                idevice = sd.query_devices(kind='input')
                odevice = sd.query_devices(kind='output')
                log.info("[VOICE] Audio devices ready",
                         input=idevice.get('name'),
                         output=odevice.get('name'))
            except Exception:
                log.warning("[VOICE] Could not query audio devices")

            self._initialized = True
            log.info("[OK] Voice service ready (initialized=True)")

        except Exception as e:
            log.error("[VOICE] Initialization failed", error=str(e))

    def _start_workers(self):
        """Manage thread lifecycle correctly. Only start if not already running."""
        with self._lock:
            self._stop_ev.clear()
            if not self._audio_thread_handle or not self._audio_thread_handle.is_alive():
                self._audio_thread_handle = threading.Thread(
                    target=self._audio_worker, daemon=True, name="voice_audio")
                self._audio_thread_handle.start()

            if not self._synth_thread_handle or not self._synth_thread_handle.is_alive():
                self._synth_thread_handle = threading.Thread(
                    target=self._synth_worker, daemon=True, name="voice_synth")
                self._synth_thread_handle.start()

            # Restart wake word listener if it was supposed to be running
            if self._is_listening_for_wake and self._wake_callback:
                if not self._wake_thread_handle or not self._wake_thread_handle.is_alive():
                    self._wake_thread_handle = threading.Thread(
                        target=self._wake_word_worker, daemon=True, name="voice_wake")
                    self._wake_thread_handle.start()

    def start_wake_word_listener(self, callback):
        """Start background listener for wake word."""
        self._wake_callback = callback
        # Don't start if already running
        if (self._is_listening_for_wake and self._wake_thread_handle
                and self._wake_thread_handle.is_alive()):
            return

        self._is_listening_for_wake = True
        log.info("[VOICE] Wake word listener started", word=settings.wake_word)
        self._wake_thread_handle = threading.Thread(
            target=self._wake_word_worker, daemon=True, name="voice_wake")
        self._wake_thread_handle.start()

    def stop_wake_word_listener(self):
        self._is_listening_for_wake = False
        log.info("[VOICE] Wake word listener stopped")

    def _wake_word_worker(self):
        """Continuous listener for wake word with follow-up logic."""
        while self._is_listening_for_wake and not self._stop_ev.is_set():
            try:
                audio = self._record_until_silence()
                if audio is None:
                    continue

                transcript = self.transcribe(audio)
                if not transcript:
                    continue

                if settings.wake_word.lower() in transcript.lower():
                    log.info("[VOICE] Wake word detected", transcript=transcript)
                    self.stop()  # Interrupt any current speech

                    # Check if there's a command after the wake word in the same transcript
                    command = self.strip_wake_word(transcript)
                    if command.strip() and command.lower() != transcript.lower():
                        # We have a command! No need to say "Yes?"
                        log.info("[VOICE] Immediate command detected", cmd=command)
                        if self._wake_callback:
                            self._wake_callback(command.strip())
                        continue

                    # Otherwise, say "Yes?" and listen for the actual command
                    self.speak("Yes?", settings.default_voice)
                    time.sleep(0.8)  # Wait for "Yes?" to synthesize and start

                    # Now listen for the actual command
                    command_audio = self._record_until_silence()
                    if command_audio is not None:
                        follow_up = self.transcribe(command_audio)
                        if follow_up.strip() and self._wake_callback:
                            log.info("[VOICE] Active follow-up command received", cmd=follow_up)
                            self._wake_callback(follow_up.strip())

                # Small sleep to prevent tight loop if nothing detected
                time.sleep(0.1)
            except Exception as e:
                log.error("[VOICE] Wake word worker error", error=str(e))
                time.sleep(1)

    def _audio_worker(self):
        """Playback thread with automatic stream recovery."""
        while not self._stop_ev.is_set():
            try:
                # Try to open output stream
                with sd.OutputStream(
                    samplerate=self.device_sr,
                    channels=1,
                    dtype="float32",
                    blocksize=4096,
                ) as stream:
                    log.info("[VOICE] Output stream opened", samplerate=self.device_sr)
                    while not self._stop_ev.is_set():
                        try:
                            item = self._play_q.get(timeout=0.2)
                            if item is _DRAIN:
                                # Send silence to flush (Jarvis style)
                                silence_len = int(self.device_sr * FINAL_SILENCE_S)
                                stream.write(
                                    np.zeros(silence_len, dtype=np.float32)
                                )
                                self._play_q.task_done()
                                continue  # Don't break, wait for next item

                            # Reset interrupt flag for new item
                            with self._lock:
                                self._interrupt_playback = False

                            if not self._stop_ev.is_set():
                                # Break large items into smaller chunks
                                chunk_size = 2048  # Smaller chunks
                                for i in range(0, len(item), chunk_size):
                                    if self._interrupt_playback or self._stop_ev.is_set():
                                        break
                                    chunk = item[i:i + chunk_size]
                                    stream.write(chunk)

                            self._play_q.task_done()
                        except queue.Empty:
                            continue
                        except Exception as e:
                            log.error(
                                "[VOICE] Stream write error, "
                                "attempting recovery", error=str(e)
                            )
                            break  # Break inner loop to re-open stream
            except Exception as e:
                if not self._stop_ev.is_set():
                    log.warning(
                        "[VOICE] Output device error, retrying in 2s...",
                        error=str(e)
                    )
                    time.sleep(2)

    def _synth_worker(self):
        """Synthesis thread."""
        while not self._stop_ev.is_set():
            try:
                item = self._synth_q.get(timeout=0.1)
                if item is None:
                    # End of stream signal, pass to audio worker to flush
                    self._play_q.put(_DRAIN)
                    self._synth_q.task_done()
                    continue  # Keep thread alive

                text, voice = item
                if not self._stop_ev.is_set():
                    # Clean text for speech before synthesis
                    clean_text = self._clean_text_for_speech(text)
                    if clean_text:
                        wav = self.synthesize(clean_text, voice)
                        if wav is not None and not self._stop_ev.is_set():
                            self._play_q.put(wav)

                self._synth_q.task_done()
            except queue.Empty:
                continue

    def _clean_text_for_speech(self, text: str) -> str:
        """Strip markdown, emojis, and symbols for natural flow."""
        import re

        # 1. Remove Markdown headers (e.g., ### Title)
        text = re.sub(r'^#+\s+', '', text, flags=re.MULTILINE)

        # 2. Remove Bold/Italic (e.g., **text**, *text*)
        text = re.sub(r'(\*\*|__)(.*?)\1', r'\2', text)
        text = re.sub(r'(\*|_)(.*?)\1', r'\2', text)

        # 3. Remove Links (e.g., [text](url)) - keep text
        text = re.sub(r'\[(.*?)\]\(.*?\)', r'\1', text)

        # 4. Remove Inline Code (e.g., `code`)
        text = re.sub(r'`(.*?)`', r'\1', text)

        # 5. Remove Emojis and special symbols
        # Range covers most common emojis and symbols
        text = re.sub(r'[^\x00-\x7F]+', '', text)

        # 6. Cleanup extra whitespace
        text = re.sub(r'\s+', ' ', text).strip()

        return text

    def synthesize(self, text: str, voice: str = "af_heart") -> Optional[np.ndarray]:
        """Convert text to audio with Jarvis-style normalization."""
        if not self._kokoro:
            return None

        try:
            # Verify voice exists in Kokoro object to avoid crash
            # kokoro-onnx voices property is a list/view of available names
            available = []
            try:
                available = list(self._kokoro.get_voices())  # Ensure list
                if not available:
                    available = list(getattr(self._kokoro, 'voices', []))
            except Exception:
                available = list(getattr(self._kokoro, 'voices', []))

            if voice not in available:
                fallback = available[0] if available else "af"
                log.warning(
                    f"[TTS] Voice '{voice}' not found in available list. "
                    f"Falling back to '{fallback}'."
                )
                voice = fallback

            samples, sr = self._kokoro.create(text, voice=voice, speed=1.0, lang="en-us")
            wav = np.array(samples, dtype=np.float32)

            peak = np.abs(wav).max()
            if peak > 0:
                wav = wav / peak * 0.95

            return self._resample(wav, self.kokoro_sr, self.device_sr)
        except Exception as e:
            log.error("[TTS] Synthesis failed", error=str(e))
            return None

    def _resample(self, wav: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
        if src_sr == dst_sr:
            return wav
        target_len = int(len(wav) * dst_sr / src_sr)
        x_in = np.linspace(0, 1, len(wav))
        x_out = np.linspace(0, 1, target_len)
        return np.interp(x_out, x_in, wav).astype(np.float32)

    def speak(self, text: str, voice: str = "af_heart"):
        """Enqueue text for synthesis and playback."""
        if not self._initialized or self._stop_ev.is_set():
            log.warning("[VOICE] Speak called but service not initialized")
            return
        log.info("[VOICE] Enqueuing text for speech", text_len=len(text), voice=voice)
        self._synth_q.put((text, voice))

    def stop(self):
        """Interrupt current synthesis and playback without killing worker threads."""
        log.info("[VOICE] Interrupting audio...")
        with self._lock:
            self._interrupt_playback = True

        # Drain queues
        try:
            while not self._play_q.empty():
                self._play_q.get_nowait()
                self._play_q.task_done()
            while not self._synth_q.empty():
                self._synth_q.get_nowait()
                self._synth_q.task_done()
        except Exception:
            pass

        self._current_buffer = ""
        self._is_first_chunk = True

    def process_token(self, token: str, voice: str = "af_heart"):
        """Handle streaming tokens using Jarvis pacing."""
        self._current_buffer += token
        chunk, remainder = self._try_flush(self._current_buffer, self._is_first_chunk)
        if chunk:
            self.speak(chunk, voice)
            self._current_buffer = remainder
            self._is_first_chunk = False

    def finalize_stream(self, voice: str = "af_heart"):
        """Flush remaining text and signal EOT."""
        if self._current_buffer.strip() and not self._stop_ev.is_set():
            self.speak(self._current_buffer.strip(), voice)

        # Signal the workers that this stream is done, but don't kill them
        self._synth_q.put(None)

        self._current_buffer = ""
        self._is_first_chunk = True

    def _try_flush(self, buf: str, is_first: bool) -> tuple[Optional[str], str]:
        """Jarvis-style flush logic."""
        s = buf.rstrip()
        n = len(s)
        if n < 5:
            return None, buf
        if self._is_sentence_end(s):
            return s, buf[n:].lstrip()
        if is_first and n >= self.first_chunk_chars:
            chunk, rest = self._word_boundary_split(s, self.first_chunk_chars)
            if chunk:
                return chunk, rest + buf[n:]
        if not is_first and n >= self.subsequent_chunk_chars:
            chunk, rest = self._word_boundary_split(s, self.subsequent_chunk_chars)
            if chunk:
                return chunk, rest + buf[n:]
        return None, buf

    def _is_decimal_dot(self, text: str, pos: int) -> bool:
        """Check if dot at pos is a decimal point (e.g. 3.14) vs sentence end."""
        if text[pos] != '.':
            return False
        if 0 < pos < len(text) - 1:
            if text[pos-1].isdigit() and text[pos+1].isdigit():
                return True
        return False

    def _is_sentence_end(self, s: str) -> bool:
        """True if s ends with a real sentence terminator (from jarvis.py)."""
        t = s.rstrip()
        if not t:
            return False
        last = t[-1]
        if last in {'!', '?'}:
            return True
        if last == '.' and not self._is_decimal_dot(t, len(t) - 1):
            return True
        return False

    def _word_boundary_split(self, s: str, max_chars: int, min_chars: int = 20):
        """Jarvis-style word boundary split."""
        t = s.rstrip()
        if len(t) < min_chars:
            return None, s
        sp = t.rfind(' ', min_chars, max_chars)
        if sp < min_chars:
            sp = max_chars if len(t) >= max_chars else len(t)
        chunk = t[:sp].rstrip()
        rest = t[sp:].lstrip() + s[len(t):]
        return chunk, rest

    def transcribe(self, audio: np.ndarray) -> str:
        """Transcribe audio using Whisper with jarvisv2 parameters."""
        if not self._whisper:
            return ""

        try:
            segments, info = self._whisper.transcribe(
                audio,
                language="en",
                beam_size=5,
                best_of=5,
                vad_filter=True,
                vad_parameters={
                    "min_silence_duration_ms": 300,
                    "speech_pad_ms": 100,
                },
                condition_on_previous_text=False,
                no_speech_threshold=0.6,
                log_prob_threshold=-1.0,
                compression_ratio_threshold=2.4,
            )

            parts = []
            for s in segments:
                text = s.text.strip()
                # Filter common hallucinations
                if text and text not in {
                    ".", "...", "you", "Thank you.", "Thanks for watching!",
                    "Thank you for watching.", "Thank you."
                }:
                    parts.append(text)

            return " ".join(parts).strip()
        except Exception as e:
            log.error("[VOICE] Transcription failed", error=str(e))
            return ""

    async def listen_and_transcribe(self) -> str:
        """Record until silence and return transcript with follow-up logic for wake words."""
        self._stop_ev.clear()
        audio = await asyncio.to_thread(self._record_until_silence)
        if audio is None or len(audio) < self.vad_sr * 0.3:
            return ""

        transcript = self.transcribe(audio)
        if not transcript:
            return ""

        # If wake word detected
        if settings.wake_word.lower() in transcript.lower():
            command = self.strip_wake_word(transcript)

            # Case 1: Wake word + Command (e.g. "Jarvis what time is it?")
            if command.strip():
                return command.strip()

            # Case 2: Wake word only (e.g. "Jarvis")
            log.info("[VOICE] Wake word detected, waiting for command...")
            self.speak("Yes?", "af_heart")

            # Give a small window for the "Yes?" to finish playing before listening again
            await asyncio.sleep(0.8)

            # Second listen loop
            audio_cmd = await asyncio.to_thread(self._record_until_silence)
            if audio_cmd is None:
                return ""

            follow_up = self.transcribe(audio_cmd)
            return follow_up.strip()

        return transcript.strip()

    def strip_wake_word(self, text: str) -> str:
        """Remove the wake word and return the actual command."""
        wake = settings.wake_word.lower()
        if not wake:
            return text
        lower = text.lower()
        idx = lower.find(wake)
        if idx == -1:
            return text
        # Remove everything up to and including the wake word
        after = text[idx + len(wake):].strip()
        # Strip leading punctuation/conjunctions
        for prefix in [",", ".", "!", "?", " please", " can you"]:
            if after.lower().startswith(prefix):
                after = after[len(prefix):].strip()
        return after if after else text

    def _record_until_silence(self) -> Optional[np.ndarray]:
        """VAD-based recording (blocking, call via to_thread)."""
        if not self._vad:
            return None

        frame_samples = int(self.vad_sr * self.vad_frame_ms / 1000)
        pre_roll = collections.deque(maxlen=self.vad_speech_frames * 2)

        voiced_frames = []
        recording = False
        num_voiced = 0
        num_silent = 0
        total_frames = 0
        max_f = int(self.max_record_s * 1000 / self.vad_frame_ms)

        raw_q = queue.Queue()

        def callback(indata, frames, time, status):
            raw_q.put(indata.copy())

        try:
            log.info("[VOICE] Recording started... speak now")
            # Try to open input stream with fallback for sample rate
            actual_sr = self.vad_sr
            try:
                stream = sd.InputStream(
                    samplerate=self.vad_sr,
                    channels=1,
                    dtype="float32",
                    blocksize=frame_samples,
                    callback=callback
                )
            except Exception as e:
                actual_sr = 44100
                log.warning(
                    f"[VOICE] Default SR {self.vad_sr} failed, "
                    f"trying {actual_sr} fallback: {e}"
                )
                stream = sd.InputStream(
                    samplerate=actual_sr,
                    channels=1,
                    dtype="float32",
                    blocksize=int(actual_sr * self.vad_frame_ms / 1000),
                    callback=callback
                )

            with stream:
                while total_frames < max_f and not self._stop_ev.is_set():
                    try:
                        frame = raw_q.get(timeout=0.1).flatten()
                    except queue.Empty:
                        continue

                    total_frames += 1

                    # If we are not at 16k, we MUST resample for VAD
                    vad_frame = frame
                    if actual_sr != self.vad_sr:
                        vad_frame = self._resample(frame, actual_sr, self.vad_sr)

                    # VAD expects int16
                    pcm = (np.clip(vad_frame, -1, 1) * 32767).astype(np.int16).tobytes()
                    # Ensure PCM is exactly the expected length for VAD (10, 20, or 30ms @ 16k)
                    # For 30ms @ 16k, that's 480 samples = 960 bytes
                    expected_len = int(self.vad_sr * self.vad_frame_ms / 1000) * 2
                    if len(pcm) > expected_len:
                        pcm = pcm[:expected_len]
                    elif len(pcm) < expected_len:
                        pcm = pcm.ljust(expected_len, b'\x00')

                    is_speech = self._vad.is_speech(pcm, self.vad_sr)

                    if not recording:
                        pre_roll.append(frame)
                        if is_speech:
                            num_voiced += 1
                            if num_voiced >= self.vad_speech_frames:
                                recording = True
                                voiced_frames.extend(list(pre_roll))
                        else:
                            num_voiced = 0
                    else:
                        voiced_frames.append(frame)
                        if is_speech:
                            num_silent = 0
                        else:
                            num_silent += 1
                            if num_silent >= self.vad_silence_frames:
                                log.info("[VOICE] Silence detected, stop recording")
                                break

            if not voiced_frames:
                return None

            final_audio = np.concatenate(voiced_frames).astype(np.float32)
            # If the final audio is not 16k, resample it for Whisper
            if actual_sr != 16000:
                final_audio = self._resample(final_audio, actual_sr, 16000)
            return final_audio

        except Exception as e:
            log.error("[VOICE] Recording failed", error=str(e))
            return None

    async def cleanup(self):
        """Stop threads and release resources."""
        log.info("[VOICE] Shutting down workers...")
        self._stop_ev.set()
        self.stop()  # Interrupt current playback and drain queues

        if self._audio_thread_handle:
            self._audio_thread_handle.join(timeout=2)
        if self._synth_thread_handle:
            self._synth_thread_handle.join(timeout=2)
        if self._wake_thread_handle:
            self._wake_thread_handle.join(timeout=2)
        log.info("[VOICE] Cleanup complete")
