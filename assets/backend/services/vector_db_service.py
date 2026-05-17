"""
Vector Database Service — ChromaDB-backed persistent vector storage.

Complements the Knowledge Graph with high-speed ANN (approximate nearest neighbour)
search. Used by RAG and the Citation Engine.

Collections:
  - "knowledge_graph": mirrors KG node embeddings for fast retrieval
  - "documents": chunked document embeddings for RAG
  - "chat_history": recent chat embeddings for context continuity
"""
import asyncio
import hashlib
import structlog
from pathlib import Path
from typing import Optional

from config.settings import settings

log = structlog.get_logger(__name__)


class VectorDBService:
    """ChromaDB-backed vector store with async interface."""

    def __init__(self):
        self._client = None
        self._collections: dict[str, object] = {}
        self._is_ready = False
        self._lock = asyncio.Lock()
        self._db_path = settings.data_dir / "chroma_db"

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    # ── Initialisation ────────────────────────────────────────────────────────

    async def initialize(self):
        """Connect to (or create) the persistent ChromaDB store."""
        async with self._lock:
            try:
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, self._init_chroma)
                self._is_ready = True
                log.info("VectorDB (ChromaDB) ready", path=str(self._db_path))
            except ImportError:
                log.warning("chromadb not installed — vector DB disabled. "
                            "Run: pip install chromadb")
            except Exception as e:
                log.error(f"VectorDB init failed: {e}")

    def _init_chroma(self):
        import chromadb
        from chromadb.config import Settings as ChromaSettings

        self._db_path.mkdir(parents=True, exist_ok=True)
        self._client = chromadb.PersistentClient(
            path=str(self._db_path),
            settings=ChromaSettings(anonymized_telemetry=False),
        )
        # Pre-create standard collections
        for name in ["knowledge_graph", "documents", "chat_history"]:
            col = self._client.get_or_create_collection(
                name=name,
                metadata={"hnsw:space": "cosine"},
            )
            self._collections[name] = col

    # ── Core CRUD ─────────────────────────────────────────────────────────────

    async def upsert(
        self,
        collection: str,
        doc_id: str,
        embedding: list[float],
        document: str = "",
        metadata: dict = None,
    ):
        """Add or update a vector in a named collection."""
        if not self._is_ready or collection not in self._collections:
            return
        col = self._collections[collection]
        meta = metadata or {}
        # ChromaDB requires string values in metadata
        clean_meta = {k: str(v) for k, v in meta.items()}

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: col.upsert(
                ids=[doc_id],
                embeddings=[embedding],
                documents=[document[:2000]],  # cap document size
                metadatas=[clean_meta],
            )
        )

    async def upsert_batch(
        self,
        collection: str,
        items: list[dict],  # each: {id, embedding, document, metadata}
    ):
        """Batch upsert for efficiency."""
        if not self._is_ready or not items or collection not in self._collections:
            return
        col = self._collections[collection]
        ids = [i["id"] for i in items]
        embeddings = [i["embedding"] for i in items]
        documents = [i.get("document", "")[:2000] for i in items]
        metadatas = [{k: str(v) for k, v in i.get("metadata", {}).items()} for i in items]

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: col.upsert(
                ids=ids, embeddings=embeddings,
                documents=documents, metadatas=metadatas,
            )
        )

    async def query(
        self,
        collection: str,
        query_embedding: list[float],
        top_k: int = 10,
        where: dict = None,
    ) -> list[dict]:
        """Semantic similarity search. Returns list of result dicts."""
        if not self._is_ready or collection not in self._collections:
            return []
        col = self._collections[collection]

        loop = asyncio.get_event_loop()
        try:
            kwargs = dict(
                query_embeddings=[query_embedding],
                n_results=top_k,
                include=["documents", "metadatas", "distances"],
            )
            if where:
                kwargs["where"] = where

            results = await loop.run_in_executor(None, lambda: col.query(**kwargs))
            out = []
            ids = results.get("ids", [[]])[0]
            docs = results.get("documents", [[]])[0]
            metas = results.get("metadatas", [[]])[0]
            dists = results.get("distances", [[]])[0]

            for doc_id, doc, meta, dist in zip(ids, docs, metas, dists):
                score = 1.0 - float(dist)  # cosine distance → similarity
                out.append({
                    "id": doc_id,
                    "document": doc,
                    "metadata": meta,
                    "score": score,
                })
            return out
        except Exception as e:
            log.warning(f"VectorDB query failed: {e}")
            return []

    async def delete(self, collection: str, doc_id: str):
        """Remove a single document from a collection."""
        if not self._is_ready or collection not in self._collections:
            return
        col = self._collections[collection]
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, lambda: col.delete(ids=[doc_id]))

    async def delete_collection(self, collection: str):
        """Wipe an entire collection."""
        if not self._is_ready or not self._client:
            return
        try:
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None, lambda: self._client.delete_collection(collection)
            )
            if collection in self._collections:
                del self._collections[collection]
        except Exception as e:
            log.warning(f"Failed to delete collection {collection}: {e}")

    async def get_collection_count(self, collection: str) -> int:
        """Return number of documents in a collection."""
        if not self._is_ready or collection not in self._collections:
            return 0
        col = self._collections[collection]
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, col.count)

    # ── Convenience helpers ───────────────────────────────────────────────────

    def make_id(self, text: str) -> str:
        """Stable doc ID from content hash."""
        return hashlib.md5(text.encode()).hexdigest()

    async def get_stats(self) -> dict:
        """Return collection sizes."""
        if not self._is_ready:
            return {"ready": False}
        stats = {"ready": True, "collections": {}}
        for name in self._collections:
            stats["collections"][name] = await self.get_collection_count(name)
        return stats
