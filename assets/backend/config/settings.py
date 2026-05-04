"""
Cyborg Backend Configuration
All secrets loaded from environment or .env file — never hardcoded.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    app_name: str = "Cyborg Backend"
    app_version: str = "17.0.0"
    debug: bool = False
    host: str = "127.0.0.1"
    port: int = 8765
    allowed_origins: list[str] = ["http://localhost:*", "http://127.0.0.1:*"]

    # Paths (relative to backend root for portability)
    base_dir: Path = Path(__file__).parent.parent.absolute()
    data_dir: Path = base_dir / "data"
    brain_dir: Path = base_dir / "brain"
    models_dir: Path = base_dir / "models"
    checkpoints_dir: Path = base_dir / "checkpoints"
    logs_dir: Path = base_dir / "logs"
    cache_dir: Path = base_dir / "cache"
    external_dir: Path = base_dir / "external"

    # Database (Resolved to absolute paths based on base_dir)
    @property
    def absolute_db_path(self) -> Path:
        return self.data_dir / "cyborg.db"

    @property
    def db_url(self) -> str:
        return f"sqlite+aiosqlite:///{self.absolute_db_path}"

    # Firebase
    @property
    def firebase_service_account_path(self) -> Path:
        return self.base_dir / "config" / "firebase-service-account.json"

    firebase_project_id: str = "cyborgai-d7a18"

    # LLM
    llm_server_host: str = "127.0.0.1"
    llm_server_port: int = 1235
    llm_server_url: str = "http://127.0.0.1:1235/v1"
    default_model: str = "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
    context_length: int = 4096
    n_gpu_layers: int = -1  # -1 = auto

    # Voice
    kokoro_model_path: str = "models/tts/kokoro-v1.0.onnx"
    kokoro_voices_path: str = "models/tts/voices.json"
    whisper_model_dir: str = "models/stt"
    whisper_model_size: str = "small"
    wake_word: str = "jarvis"
    default_voice: str = "af_sarah"

    # Audio/VAD Tuning
    vad_sr: int = 16000
    vad_frame_ms: int = 30
    vad_silence_frames: int = 20  # 600ms
    vad_speech_frames: int = 8    # 240ms
    vad_aggressiveness: int = 3   # 0-3
    max_record_s: int = 20
    device_sr: int = 44100

    # Embeddings
    embedding_model: str = "all-MiniLM-L6-v2"
    embedding_device: str = "cpu"

    @property
    def embedding_cache_dir(self) -> str:
        return str(self.cache_dir / "embeddings")

    # Redis (optional caching layer)
    redis_url: str = "redis://localhost:6379/0"
    use_redis: bool = False

    # Rate limiting
    rate_limit_per_minute: int = 60
    rate_limit_per_hour: int = 1000

    # GitHub
    github_token: str = ""  # Set via env: GITHUB_TOKEN

    # Security
    secret_key: str = "change-me-in-production-use-env-var"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24

    # Features
    enable_voice: bool = True
    enable_vision: bool = False  # Requires MediaPipe
    enable_world_monitor: bool = True
    offline_mode: bool = False

    def setup_dirs(self):
        """Create all required directories."""
        dirs = [
            self.data_dir, self.brain_dir, self.models_dir, self.checkpoints_dir,
            self.logs_dir, self.cache_dir, self.external_dir,
            self.base_dir / "config",
            self.models_dir / "llm",
            self.models_dir / "tts",
            self.models_dir / "stt",
        ]
        for d in dirs:
            d.mkdir(parents=True, exist_ok=True)


@lru_cache()
def get_settings() -> Settings:
    s = Settings()
    s.setup_dirs()
    return s


settings = get_settings()
