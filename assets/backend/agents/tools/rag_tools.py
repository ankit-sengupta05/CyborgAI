"""
RAG Tools — LangChain tools for RAG-powered knowledge retrieval.

These tools connect the chat agent to the Active RAG system,
providing semantic search, graph traversal, and conversation summarization.
"""
import asyncio
import structlog
from langchain_core.tools import tool

log = structlog.get_logger(__name__)

_app_state = None


def set_app_state(state):
    """Called during app startup to inject FastAPI app.state."""
    global _app_state
    _app_state = state


@tool
def rag_search(query: str) -> str:
    """Search the user's knowledge base using hybrid RAG (embeddings + graph + vault).
    This is the primary search tool — use it for any knowledge-related questions.

    Args:
        query: The search query or question.
    """
    import asyncio

    if not _app_state or not hasattr(_app_state, "rag_service"):
        return "RAG service not available."

    try:
        rag = _app_state.rag_service

        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, rag.retrieve(query, top_k=8))
                result = future.result(timeout=15)
        else:
            result = asyncio.run(rag.retrieve(query, top_k=8))

        context = result.get("context", "")
        sources = result.get("sources", [])
        total = result.get("total_results", 0)

        if not context:
            return f"No relevant information found for '{query}'."

        output = f"📚 Found {total} relevant results:\n\n{context}\n\n"
        if sources:
            output += "Sources:\n"
            for s in sources[:5]:
                output += f"  • {s.get('label', 'Unknown')} ({s.get('type', '')})\n"
        return output

    except Exception as e:
        return f"RAG search error: {e}"


@tool
def get_graph_context(entity: str) -> str:
    """Get detailed context about a specific entity from the knowledge graph,
    including its relationships and connected concepts.

    Args:
        entity: Name of the entity to look up.
    """
    if not _app_state:
        return "Graph service not available."

    try:
        graph = _app_state.graph_service

        # Search for the entity
        results = []
        entity_lower = entity.lower()
        for nid, data in graph._nodes.items():
            if entity_lower in data.get("label", "").lower():
                results.append((nid, data))

        if not results:
            return f"Entity '{entity}' not found in knowledge graph."

        output = f"Knowledge Graph context for '{entity}':\n\n"
        for nid, data in results[:3]:
            output += f"**{data.get('label', '')}** ({data.get('content_type', '')})\n"
            content = data.get("content", "")
            if content:
                output += f"{content[:300]}\n\n"

            # Get neighbors
            if nid in graph._graph:
                neighbors = list(graph._graph.neighbors(nid))
                if neighbors:
                    output += "Connected to:\n"
                    for n in neighbors[:10]:
                        n_data = graph._nodes.get(n, {})
                        n_label = n_data.get("label", n)
                        output += f"  → {n_label}\n"
                    output += "\n"

        # Get community info
        if results:
            nid = results[0][0]
            community = graph._communities.get(nid)
            if community is not None and community in graph._community_meta:
                meta = graph._community_meta[community]
                output += f"Cluster: {meta.get('name', 'Unknown')} — {meta.get('summary', '')}\n"

        return output

    except Exception as e:
        return f"Graph context error: {e}"


@tool
def get_chat_sync_status() -> str:
    """Check the current status of chat-to-knowledge-graph synchronization."""
    if not _app_state or not hasattr(_app_state, "chat_sync_service"):
        return "Chat sync service not available."

    try:
        status = _app_state.chat_sync_service.get_sync_status()
        return (
            f"Chat Sync Status:\n"
            f"  Last sync: {status.get('last_sync', 'Never')}\n"
            f"  Pending messages: {status.get('pending_messages', 0)}\n"
            f"  Pending sessions: {status.get('pending_sessions', 0)}\n"
            f"  Total synced sessions: {status.get('synced_sessions_total', 0)}\n"
            f"  Service running: {status.get('running', False)}"
        )
    except Exception as e:
        return f"Sync status error: {e}"


ALL_RAG_TOOLS = [
    rag_search,
    get_graph_context,
    get_chat_sync_status,
]
