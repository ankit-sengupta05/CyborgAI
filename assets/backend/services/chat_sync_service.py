"""
Chat Sync Service — Ingests chat history into the Knowledge Graph.

Handles:
- Periodic background sync of chat sessions to KG
- Entity/relationship extraction from conversations
- Context window tracking and auto-summarization
- Graceful shutdown sync
"""
import asyncio
import hashlib
import datetime
import structlog
from typing import Optional

from services.database import ChatSession, GraphNodeDB, GraphEdgeDB, get_db

log = structlog.get_logger(__name__)


class ChatSyncService:
    """Manages bidirectional sync between chat history and Knowledge Graph."""

    def __init__(self, graph_service, llm_service, vault_service):
        self._graph = graph_service
        self._llm = llm_service
        self._vault = vault_service
        self._sync_interval = 300  # 5 minutes
        self._max_unsynced_messages = 20
        self._synced_sessions: set[str] = set()
        self._pending_messages: dict[str, list[dict]] = {}
        self._sync_task: Optional[asyncio.Task] = None
        self._running = False
        self._last_sync: Optional[datetime.datetime] = None

    @property
    def last_sync(self) -> Optional[str]:
        return self._last_sync.isoformat() if self._last_sync else None

    async def start(self):
        """Start the background sync loop."""
        self._running = True
        self._sync_task = asyncio.create_task(self._sync_loop())
        log.info("Chat sync service started", interval=self._sync_interval)

    async def stop(self):
        """Stop sync loop and do final sync."""
        self._running = False
        if self._sync_task:
            self._sync_task.cancel()
            try:
                await self._sync_task
            except asyncio.CancelledError:
                pass
        # Final sync before shutdown
        await self.sync_all_pending()
        log.info("Chat sync service stopped")

    async def _sync_loop(self):
        """Background loop that periodically syncs chat to KG."""
        while self._running:
            try:
                await asyncio.sleep(self._sync_interval)
                await self.sync_all_pending()
            except asyncio.CancelledError:
                break
            except Exception as e:
                log.error(f"Sync loop error: {e}")

    async def track_message(self, session_id: str, message: dict):
        """Track a new message for pending sync.

        Args:
            session_id: Chat session identifier.
            message: Message dict with 'role' and 'content'.
        """
        if session_id not in self._pending_messages:
            self._pending_messages[session_id] = []

        self._pending_messages[session_id].append({
            **message,
            "timestamp": datetime.datetime.now().isoformat(),
        })

        # Auto-sync if too many unsynced messages
        if len(self._pending_messages[session_id]) >= self._max_unsynced_messages:
            log.info(f"Auto-syncing session {session_id}: {self._max_unsynced_messages} messages reached")
            await self._sync_session(session_id)

    async def sync_all_pending(self):
        """Sync all pending chat sessions to Knowledge Graph."""
        if not self._pending_messages:
            return

        synced_count = 0
        for session_id in list(self._pending_messages.keys()):
            try:
                await self._sync_session(session_id)
                synced_count += 1
            except Exception as e:
                log.error(f"Failed to sync session {session_id}: {e}")

        self._last_sync = datetime.datetime.now()
        if synced_count > 0:
            log.info(f"Synced {synced_count} chat sessions to Knowledge Graph")

    async def _sync_session(self, session_id: str):
        """Sync a single chat session to the Knowledge Graph.

        Extracts entities, relationships, and key facts from the conversation
        and creates KG nodes/edges for them.
        """
        messages = self._pending_messages.get(session_id, [])
        if not messages:
            return

        # Build conversation text
        conversation_text = self._build_conversation_text(messages)
        if not conversation_text.strip():
            self._pending_messages.pop(session_id, None)
            return

        # 1. Extract entities and facts from conversation
        extracted = await self._extract_from_conversation(conversation_text)

        # 2. Create KG nodes for the conversation
        conv_node_id = hashlib.md5(f"chat_{session_id}".encode()).hexdigest()[:12]
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

        conv_node = {
            "id": conv_node_id,
            "label": f"Chat: {self._get_topic(messages)}",
            "content": conversation_text[:2000],
            "content_type": "chat_history",
            "source": f"chat:{session_id}",
        }

        async with get_db() as db:
            await GraphNodeDB.create(db, conv_node)
        self._graph._add_node_to_graph(conv_node)

        # 3. Create entity nodes and link them
        for entity in extracted.get("entities", []):
            label = entity.get("label", "").strip()
            if not label or len(label) < 2:
                continue

            ent_id = hashlib.md5(label.lower().encode()).hexdigest()[:12]

            if ent_id not in self._graph._nodes:
                ent_node = {
                    "id": ent_id,
                    "label": label,
                    "content_type": entity.get("type", "concept"),
                    "source": f"chat:{session_id}",
                }
                async with get_db() as db:
                    await GraphNodeDB.create(db, ent_node)
                self._graph._add_node_to_graph(ent_node)

            # Link conversation to entity
            edge = {"source": conv_node_id, "target": ent_id, "type": "DISCUSSES", "weight": 0.9}
            if not self._graph._graph.has_edge(conv_node_id, ent_id):
                async with get_db() as db:
                    await GraphEdgeDB.create(db, edge)
                self._graph._add_edge_to_graph(edge)

        # 4. Create relationship edges
        for rel in extracted.get("relationships", []):
            s_label = rel.get("source", "").strip().lower()
            t_label = rel.get("target", "").strip().lower()
            if s_label and t_label:
                s_id = hashlib.md5(s_label.encode()).hexdigest()[:12]
                t_id = hashlib.md5(t_label.encode()).hexdigest()[:12]
                if s_id in self._graph._nodes and t_id in self._graph._nodes:
                    edge = {
                        "source": s_id,
                        "target": t_id,
                        "type": rel.get("type", "LINKED_TO"),
                        "weight": rel.get("weight", 0.7),
                    }
                    if not self._graph._graph.has_edge(s_id, t_id):
                        async with get_db() as db:
                            await GraphEdgeDB.create(db, edge)
                        self._graph._add_edge_to_graph(edge)

        # 5. Save to vault as markdown
        try:
            topic = self._get_topic(messages)
            md_content = f"""---
session_id: {session_id}
synced_at: {timestamp}
topic: {topic}
messages: {len(messages)}
---

# Chat: {topic}

{conversation_text[:3000]}
"""
            await self._vault.create_note(
                title=f"Chat_{topic[:30]}_{session_id[:8]}",
                content=md_content,
                folder="Archive",
                tags=["chat-history", "synced"],
                note_type="chat_log",
            )
        except Exception as e:
            log.debug(f"Vault save skipped: {e}")

        # Clear pending messages for this session
        self._pending_messages.pop(session_id, None)
        self._synced_sessions.add(session_id)

    def _build_conversation_text(self, messages: list[dict]) -> str:
        """Build readable text from message list."""
        parts = []
        for m in messages:
            role = m.get("role", "unknown").capitalize()
            content = m.get("content", "")
            if content:
                parts.append(f"{role}: {content}")
        return "\n\n".join(parts)

    def _get_topic(self, messages: list[dict]) -> str:
        """Extract a short topic from the first user message."""
        for m in messages:
            if m.get("role") == "user":
                content = m.get("content", "")
                # First 50 chars, clean up
                topic = content[:50].replace("\n", " ").strip()
                if len(topic) > 40:
                    topic = topic[:40] + "..."
                return topic
        return "General"

    async def _extract_from_conversation(self, text: str) -> dict:
        """Use LLM to extract entities and relationships from conversation."""
        if not self._llm.is_ready:
            return {"entities": [], "relationships": [], "facts": []}

        prompt = f"""Extract key entities, relationships, and facts from this conversation.
Focus on: people, topics, decisions, tasks, and knowledge shared.

Return ONLY valid JSON:
{{
  "entities": [{{"label": "Entity Name", "type": "person/topic/task/decision/concept"}}],
  "relationships": [
    {{"source": "Entity A", "target": "Entity B", "type": "DISCUSSED/DECIDED/ASSIGNED/LINKED_TO", "weight": 0.8}}
  ],
  "facts": ["Key fact or decision from conversation"]
}}

CONVERSATION:
{text[:2000]}"""

        try:
            response = await self._llm.complete(prompt, temperature=0.1, max_tokens=800)
            import re
            import json
            match = re.search(r"\{.*\}", response, re.DOTALL)
            if match:
                try:
                    return json.loads(match.group(0))
                except json.JSONDecodeError:
                    pass
        except Exception as e:
            log.warning(f"Chat entity extraction failed: {e}")

        return {"entities": [], "relationships": [], "facts": []}

    def get_sync_status(self) -> dict:
        """Get current sync status for the frontend."""
        pending_count = sum(len(msgs) for msgs in self._pending_messages.values())
        return {
            "last_sync": self.last_sync,
            "pending_messages": pending_count,
            "pending_sessions": len(self._pending_messages),
            "synced_sessions_total": len(self._synced_sessions),
            "running": self._running,
        }
