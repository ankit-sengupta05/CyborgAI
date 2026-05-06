"""
RAG Service — Active Retrieval-Augmented Generation with Knowledge Graph.

Combines:
- Embedding-based semantic search (EmbeddingService)
- Knowledge Graph traversal (GraphService)
- LangChain document processing for fast chunking
- Context window management with token counting
- Conversation-aware retrieval
"""
import asyncio
import structlog
from typing import Optional

from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_core.documents import Document

from config.settings import settings

log = structlog.get_logger(__name__)


class RAGService:
    """Active RAG engine that retrieves context from the Knowledge Graph
    and embeddings to augment LLM responses."""

    def __init__(self, graph_service, embedding_service, vault_service, llm_service):
        self._graph = graph_service
        self._embeddings = embedding_service
        self._vault = vault_service
        self._llm = llm_service
        self._splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            separators=["\n\n", "\n", ". ", " ", ""],
        )
        self._max_context_tokens = settings.context_length * 0.6  # Reserve 60% for RAG context
        self._is_ready = False

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    async def initialize(self):
        """Initialize RAG service after dependencies are ready."""
        self._is_ready = True
        log.info("RAG service initialized")

    async def retrieve(
        self,
        query: str,
        top_k: int = 10,
        include_graph_context: bool = True,
        max_tokens: int = 2000,
    ) -> dict:
        """Retrieve relevant context for a query using hybrid search.

        Args:
            query: The user's question or search query.
            top_k: Maximum number of results to return.
            include_graph_context: Whether to include graph neighbor context.
            max_tokens: Approximate max tokens for returned context.

        Returns:
            dict with 'context' (str), 'sources' (list), 'graph_paths' (list).
        """
        results = []
        sources = []
        graph_paths = []

        # 1. Semantic search over KG nodes (embedding similarity)
        if self._embeddings.is_ready:
            kg_results = await self._graph.search(query, limit=top_k)
            for node in kg_results:
                score = node.get("score", 0.0)
                if score > 0.3:
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
                        "type": node.get("content_type", "text"),
                        "score": score,
                    })

        # 2. Graph traversal — find related entities
        if include_graph_context and results:
            for result in results[:3]:  # Top 3 results
                label = result.get("label", "")
                neighbors = self._get_graph_neighbors(label, depth=2)
                for neighbor in neighbors:
                    n_data = self._graph._nodes.get(neighbor, {})
                    if n_data:
                        graph_paths.append({
                            "from": label,
                            "to": n_data.get("label", ""),
                            "relationship": "related",
                        })
                        # Add neighbor content if not already present
                        n_content = n_data.get("content", "")
                        if n_content and n_content not in [r["content"] for r in results]:
                            results.append({
                                "content": n_content[:500],
                                "label": n_data.get("label", ""),
                                "source": "graph_neighbor",
                                "score": 0.5,
                                "type": "kg_graph",
                            })

        # 3. Vault search — search markdown notes
        try:
            vault_results = await self._vault.search_notes(query)
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

        # 4. Sort by score and truncate to token limit
        results.sort(key=lambda x: x.get("score", 0), reverse=True)
        context = self._build_context(results, max_tokens)

        return {
            "context": context,
            "sources": sources[:top_k],
            "graph_paths": graph_paths[:10],
            "total_results": len(results),
        }

    def _get_graph_neighbors(self, label: str, depth: int = 2) -> list[str]:
        """Get neighboring node IDs from the knowledge graph."""
        # Find node by label
        node_id = None
        for nid, data in self._graph._nodes.items():
            if data.get("label", "").lower() == label.lower():
                node_id = nid
                break

        if not node_id or node_id not in self._graph._graph:
            return []

        neighbors = set()
        current_level = {node_id}
        for _ in range(depth):
            next_level = set()
            for n in current_level:
                if n in self._graph._graph:
                    for neighbor in self._graph._graph.neighbors(n):
                        if neighbor != node_id and neighbor not in neighbors:
                            next_level.add(neighbor)
                            neighbors.add(neighbor)
            current_level = next_level

        return list(neighbors)[:20]  # Cap at 20 neighbors

    def _build_context(self, results: list[dict], max_tokens: int) -> str:
        """Build a formatted context string from retrieval results."""
        if not results:
            return ""

        context_parts = []
        approx_tokens = 0

        for r in results:
            content = r.get("content", "").strip()
            if not content:
                continue

            # Rough token estimation (1 token ≈ 4 chars)
            chunk_tokens = len(content) // 4
            if approx_tokens + chunk_tokens > max_tokens:
                # Truncate last chunk to fit
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

    async def augment_messages(
        self,
        messages: list[dict],
        system_prompt: str = "",
    ) -> list[dict]:
        """Augment chat messages with RAG context.

        Extracts the latest user query, retrieves relevant context,
        and injects it into the system prompt.

        Args:
            messages: Chat messages list.
            system_prompt: Base system prompt to augment.

        Returns:
            Modified messages list with RAG context injected.
        """
        # Find the latest user message
        user_query = ""
        for msg in reversed(messages):
            if msg.get("role") == "user":
                user_query = msg.get("content", "")
                break

        if not user_query:
            return messages

        # Retrieve context
        retrieval = await self.retrieve(user_query, top_k=8, max_tokens=1500)
        context = retrieval.get("context", "")

        if not context:
            return messages

        # Build RAG-augmented system prompt
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

        # Replace or add system message
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

    async def ingest_document(self, text: str, metadata: dict = None) -> list[Document]:
        """Split and prepare a document for ingestion using LangChain splitters.

        Args:
            text: Raw document text.
            metadata: Optional metadata dict.

        Returns:
            List of LangChain Document chunks.
        """
        docs = self._splitter.create_documents(
            [text],
            metadatas=[metadata or {}],
        )
        log.info(f"Split document into {len(docs)} chunks")
        return docs
