"""
RAG Service — Active Retrieval-Augmented Generation with Vector DB + Knowledge Graph.

Combines:
- ChromaDB vector search (VectorDBService) — primary, fast ANN
- Knowledge Graph traversal (GraphService) — semantic neighbourhood
- Vault search — markdown notes
- Context window management with token counting
"""
import asyncio
import structlog
from typing import Optional

from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document

from config.settings import settings

log = structlog.get_logger(__name__)


class RAGService:
    """Active RAG engine that retrieves context using Vector DB + Knowledge Graph."""

    def __init__(self, graph_service, embedding_service, vault_service, llm_service,
                 vector_db_service=None):
        self._graph = graph_service
        self._embeddings = embedding_service
        self._vault = vault_service
        self._llm = llm_service
        self._vector_db = vector_db_service
        self._splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            separators=["\n\n", "\n", ". ", " ", ""],
        )
        self._max_context_tokens = settings.context_length * 0.6
        self._is_ready = False

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    async def initialize(self):
        """Initialize RAG service after dependencies are ready."""
        # Proactively start content index initialization
        from services.cyborg_content_index import ContentIndex
        if not hasattr(self, '_content_index'):
            self._content_index = ContentIndex()
            # Background the initialization so it doesn't block the startup sequence
            asyncio.create_task(self._content_index.initialize())

        self._is_ready = True
        log.info("RAG service initialized",
                 vector_db=self._vector_db.is_ready if self._vector_db else False)

    # ── Core retrieval ─────────────────────────────────────────────────────────

    async def retrieve(
        self,
        query: str,
        top_k: int = 10,
        include_graph_context: bool = True,
        max_tokens: int = 2000,
    ) -> dict:
        """Hybrid retrieval: VectorDB → KG traversal → Vault."""

        # Clean noisy stop words
        stop_words = {
            "what", "is", "my", "the", "a", "an", "can", "you", "tell",
            "me", "about", "show", "whats", "find", "hi", "hello", "hey",
            "how", "are", "there", "good", "morning", "afternoon", "evening",
            "thanks", "thank", "please", "ok", "okay", "yes", "no"
        }
        clean_query = " ".join([w for w in query.lower().split() if w not in stop_words]).strip()
        
        # Skip retrieval for purely conversational or excessively short queries
        if not clean_query or len(clean_query) < 3:
            log.info(f"RAG: Query '{query}' too generic/short, skipping retrieval.")
            return {
                "context": "",
                "sources": [],
                "graph_paths": [],
                "total_results": 0,
            }

        log.info(f"RAG: Searching for '{clean_query}'")

        results: list[dict] = []
        sources: list[dict] = []
        graph_paths: list[dict] = []

        # ── 1. Content Index Search (BM25 + Hybrid) ───────────────────────────
        try:
            from services.cyborg_content_index import ContentIndex
            
            # Lazy initialize if not already done (safety)
            if not hasattr(self, '_content_index'):
                self._content_index = ContentIndex()
            
            # Ensure it's fully initialized before search (non-blocking if already done)
            await self._content_index.initialize()
                
            # Perform hybrid semantic + BM25 keyword search
            content_results = self._content_index.search(clean_query, top_k=top_k, min_score=0.15)
            
            for r in content_results:
                score = r.get("score", 0.0)
                results.append({
                    "content": r.get("best_chunk", ""),
                    "label": r.get("filename", ""),
                    "source": r.get("source", ""),
                    "score": score,
                    "type": "content_index",
                })
                sources.append({
                    "id": r.get("source"),
                    "label": r.get("filename", ""),
                    "source": r.get("source", ""),
                    "type": r.get("ext", "document"),
                    "score": score,
                })
        except Exception as e:
            log.error(f"Content Index (BM25+Hybrid) search failed: {e}")

        # ── 2. KG semantic search (in-memory embedding fallback) ──────────────
        if self._embeddings.is_ready and len(results) < top_k:
            try:
                kg_results = await self._graph.search(clean_query, limit=top_k)
                seen_ids = {r.get("id") for r in results}
                for node in kg_results:
                    score = node.get("score", 0.0)
                    if score > 0.3 and node.get("id") not in seen_ids:
                        results.append({
                            "content": node.get("content", ""),
                            "label": node.get("label", ""),
                            "source": node.get("source", "knowledge_graph"),
                            "score": score,
                            "type": "kg_semantic",
                        })
                        sources.append({
                            "id": node.get("id"),
                            "label": node.get("label"),
                            "source": node.get("source", "knowledge_graph"),
                            "type": node.get("content_type", "text"),
                            "score": score,
                        })
            except Exception as e:
                log.debug(f"KG search failed: {e}")

        # ── 3. KG graph traversal (neighbourhood) ─────────────────────────────
        if include_graph_context and results:
            for result in results[:3]:
                label = result.get("label", "")
                neighbours = self._get_graph_neighbors(label, depth=2)
                for neighbour in neighbours:
                    n_data = self._graph._nodes.get(neighbour, {})
                    if n_data:
                        graph_paths.append({
                            "from": label,
                            "to": n_data.get("label", ""),
                            "relationship": "related",
                        })
                        n_content = n_data.get("content", "")
                        if n_content and n_content not in [r["content"] for r in results]:
                            results.append({
                                "content": n_content[:500],
                                "label": n_data.get("label", ""),
                                "source": "graph_neighbor",
                                "score": 0.4,
                                "type": "kg_graph",
                            })

        # ── 4. Vault search ────────────────────────────────────────────────────
        try:
            vault_results = await self._vault.search_notes(clean_query)
            for note in vault_results:
                content = note.get("content", "")
                if content:
                    results.append({
                        "content": content[:1000],
                        "label": note.get("title", ""),
                        "source": f"vault:{note.get('id', '')}",
                        "score": note.get("score", 0.5),
                        "type": "vault",
                    })
                    sources.append({
                        "id": note.get("id"),
                        "label": note.get("title"),
                        "type": "vault_note",
                        "score": note.get("score", 0.5),
                    })
        except Exception as e:
            log.debug(f"Vault search skipped: {e}")

        # ── Sort and build context ─────────────────────────────────────────────
        results.sort(key=lambda x: x.get("score", 0), reverse=True)
        context = self._build_context(results, max_tokens)

        log.info("RAG retrieval complete",
                 query=query,
                 results_found=len(results),
                 sources=[s["label"] for s in sources[:3]],
                 context_len=len(context))

        return {
            "context": context,
            "sources": sources[:top_k],
            "graph_paths": graph_paths[:10],
            "total_results": len(results),
        }

    def _get_graph_neighbors(self, label: str, depth: int = 2) -> list[str]:
        """Get neighbouring node IDs from the knowledge graph."""
        node_id = None
        for nid, data in self._graph._nodes.items():
            if data.get("label", "").lower() == label.lower():
                node_id = nid
                break

        if not node_id or node_id not in self._graph._graph:
            return []

        neighbours = set()
        current_level = {node_id}
        for _ in range(depth):
            next_level = set()
            for n in current_level:
                if n in self._graph._graph:
                    for nb in self._graph._graph.neighbors(n):
                        if nb != node_id and nb not in neighbours:
                            next_level.add(nb)
                            neighbours.add(nb)
            current_level = next_level

        return list(neighbours)[:20]

    def _build_context(self, results: list[dict], max_tokens: int) -> str:
        """Build formatted context from retrieval results, filtering out refusals."""
        if not results:
            return ""

        context_parts = []
        approx_tokens = 0
        
        # Patterns to exclude (prevents poisoning from past failed turns/refusals/loops)
        REFUSAL_PATTERNS = [
            "cannot log in", "unable to log in", "as an ai", "security and privacy reasons",
            "security protocols", "strict security", "unable to directly", "cannot directly",
            "log in yourself", "visit the official", "cannot access personal", "private accounts",
            "<tool>", "</tool>", "*using tool:*", "I see you want to log into Instagram. I will use my automation tools"
        ]

        for r in results:
            content = r.get("content", "").strip()
            if not content:
                continue
                
            # Skip if content looks like a past refusal (Context Poisoning Protection)
            lower_content = content.lower()
            if any(p in lower_content for p in REFUSAL_PATTERNS):
                continue

            chunk_tokens = len(content) // 4
            if approx_tokens + chunk_tokens > max_tokens:
                remaining = max_tokens - approx_tokens
                if remaining > 50:
                    content = content[:remaining * 4]
                else:
                    break

            label = r.get("label", "")
            source_type = r.get("type", "")
            header = f"[{source_type}] {label}" if label else f"[{source_type}]"
            context_parts.append(f"--- {header} ---\n{content}")
            approx_tokens += chunk_tokens

        return "\n\n".join(context_parts)

    # ── Message augmentation ───────────────────────────────────────────────────

    async def augment_messages(
        self,
        messages: list[dict],
        system_prompt: str = "",
    ) -> list[dict]:
        """Augment chat messages with RAG context."""
        user_query = ""
        for msg in reversed(messages):
            if msg.get("role") == "user":
                content = msg.get("content", "")
                if isinstance(content, list):
                    for part in content:
                        if isinstance(part, dict) and part.get("type") == "text":
                            user_query = part.get("text", "")
                            break
                else:
                    user_query = content
                break

        if not user_query:
            return messages

        retrieval = await self.retrieve(user_query, top_k=8, max_tokens=1500)
        context = retrieval.get("context", "")

        if not context:
            return messages

        rag_prompt = (
            f"{system_prompt}\n\n"
            "## Retrieved Knowledge Context\n"
            "Use the following context from the user's knowledge base to inform your response. "
            "Cite sources when relevant. If the context doesn't contain relevant information, "
            "respond based on your training knowledge and say so.\n\n"
            f"{context}\n\n"
            "---\n"
            f"Sources found: {retrieval.get('total_results', 0)}"
        )

        augmented = []
        has_system = False
        for msg in messages:
            if msg.get("role") == "system":
                augmented.append({"role": "system", "content": rag_prompt})
                has_system = True
            else:
                augmented.append(msg)

        if not has_system:
            augmented.insert(0, {"role": "system", "content": rag_prompt})

        return augmented

    # ── VectorDB sync ──────────────────────────────────────────────────────────

    async def sync_node_to_vector_db(self, node: dict):
        """Upsert a single KG node's embedding into the VectorDB."""
        if not self._vector_db or not self._vector_db.is_ready:
            return
        if not self._embeddings.is_ready:
            return

        content = node.get("content", node.get("label", ""))
        if not content:
            return

        try:
            embedding = await self._embeddings.embed(content)
            await self._vector_db.upsert(
                collection="knowledge_graph",
                doc_id=node["id"],
                embedding=embedding,
                document=content[:2000],
                metadata={
                    "label": node.get("label", ""),
                    "source": node.get("source", ""),
                    "content_type": node.get("content_type", "text"),
                },
            )
        except Exception as e:
            log.debug(f"VectorDB sync failed for node {node.get('id')}: {e}")

    async def sync_all_nodes_to_vector_db(self):
        """Bulk sync all KG nodes to VectorDB (run at startup or after bulk ingest)."""
        if not self._vector_db or not self._vector_db.is_ready:
            return
        if not self._embeddings.is_ready:
            return

        nodes = list(self._graph._nodes.values())
        log.info(f"Syncing {len(nodes)} KG nodes to VectorDB...")

        batch = []
        for node in nodes:
            content = node.get("content", node.get("label", ""))
            if not content:
                continue
            try:
                emb = await self._embeddings.embed(content)
                batch.append({
                    "id": node["id"],
                    "embedding": emb,
                    "document": content[:2000],
                    "metadata": {
                        "label": node.get("label", ""),
                        "source": node.get("source", ""),
                        "content_type": node.get("content_type", "text"),
                    },
                })
                if len(batch) >= 50:
                    await self._vector_db.upsert_batch("knowledge_graph", batch)
                    batch = []
                    await asyncio.sleep(0.05)  # Yield to event loop to prevent UI hangs
            except Exception:
                continue

        if batch:
            await self._vector_db.upsert_batch("knowledge_graph", batch)

        log.info(f"VectorDB sync complete: {len(nodes)} nodes indexed")

    # ── Document ingestion ─────────────────────────────────────────────────────

    async def ingest_document(self, text: str, metadata: dict = None) -> list[Document]:
        """Split and prepare a document for ingestion."""
        docs = self._splitter.create_documents(
            [text],
            metadatas=[metadata or {}],
        )
        log.info(f"Split document into {len(docs)} chunks")
        return docs
