"""
Embedding Service - local sentence-transformers with offline fallback.
Model is cached after first download; subsequent boots work offline.
"""
import asyncio
import numpy as np
import structlog

from config.settings import settings

log = structlog.get_logger(__name__)


class EmbeddingService:
    def __init__(self):
        self._model = None
        self._is_ready = False
        self._dimension = 384  # all-MiniLM-L6-v2
        self._lock = asyncio.Lock()

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    @property
    def dimension(self) -> int:
        return self._dimension

    async def initialize(self):
        async with self._lock:
            try:
                loop = asyncio.get_event_loop()
                self._model = await loop.run_in_executor(None, self._load_model)
                self._is_ready = True
                log.info(f"Embedding model loaded: {settings.embedding_model}")
            except Exception as e:
                log.error(f"Failed to load embedding model: {e}")
                # Check for common dependency issues
                try:
                    import torch
                    log.debug(
                        f"Embedding diagnostic - Torch version: {torch.__version__}, "
                        f"CUDA: {torch.cuda.is_available()}"
                    )
                    import transformers
                    log.debug(
                        "Embedding diagnostic - Transformers version: "
                        f"{transformers.__version__}"
                    )
                except ImportError as ie:
                    log.error(f"Embedding diagnostic - Missing dependency: {ie}")

                log.warning("Falling back to random embeddings (semantic search disabled)")
                self._is_ready = False

    def _load_model(self):
        try:
            from sentence_transformers import SentenceTransformer
        except ImportError as e:
            log.error(f"Required libraries for embeddings not found: {e}")
            raise

        cache_dir = settings.cache_dir / "sentence_transformers"
        cache_dir.mkdir(parents=True, exist_ok=True)

        # Check if model is already cached locally
        model_cache = cache_dir / settings.embedding_model.replace("/", "_")
        local_model_exists = (
            model_cache.exists() and any(model_cache.iterdir())
            if model_cache.exists() else False
        )

        try:
            if local_model_exists:
                # Load from local cache only (fully offline)
                log.info(f"Loading embedding model from local cache: {model_cache}")
                return SentenceTransformer(
                    str(model_cache),
                    device=settings.embedding_device,
                )
            else:
                # First boot: try to download and cache
                log.info(f"Downloading embedding model: {settings.embedding_model}")
                model = SentenceTransformer(
                    settings.embedding_model,
                    device=settings.embedding_device,
                    cache_folder=str(cache_dir),
                )
                # Save locally for offline use
                model.save(str(model_cache))
                log.info(f"Model cached at: {model_cache}")
                return model
        except Exception as e:
            log.warning(f"Could not load/download model: {e}. Semantic search will be disabled.")
            raise

    async def embed(self, text: str) -> list[float]:
        if not self._is_ready or self._model is None:
            return [0.0] * self._dimension
        loop = asyncio.get_event_loop()
        embedding = await loop.run_in_executor(
            None, lambda: self._model.encode(text, normalize_embeddings=True))
        return embedding.tolist()

    async def embed_batch(self, texts: list[str]) -> list[list[float]]:
        if not self._is_ready or self._model is None:
            return [[0.0] * self._dimension] * len(texts)
        loop = asyncio.get_event_loop()
        embeddings = await loop.run_in_executor(
            None, lambda: self._model.encode(
                texts, normalize_embeddings=True, batch_size=128, show_progress_bar=False))
        return embeddings.tolist()

    def cosine_similarity(self, a: list[float], b: list[float]) -> float:
        a_arr, b_arr = np.array(a), np.array(b)
        dot = np.dot(a_arr, b_arr)
        norm_a, norm_b = np.linalg.norm(a_arr), np.linalg.norm(b_arr)
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return float(dot / (norm_a * norm_b))

    def top_k_similar(self, query_embedding, candidate_embeddings, k=10):
        if not candidate_embeddings:
            return []
        q = np.array(query_embedding)
        C = np.array(candidate_embeddings)
        norms = np.linalg.norm(C, axis=1, keepdims=True)
        norms = np.where(norms == 0, 1, norms)
        scores = (C / norms) @ (q / (np.linalg.norm(q) or 1))
        top_indices = np.argsort(scores)[::-1][:k]
        return [(int(i), float(scores[i])) for i in top_indices]
