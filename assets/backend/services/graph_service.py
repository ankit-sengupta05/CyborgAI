"""
Graph Service — Knowledge graph with Leiden community detection.
Graphify-style visualization + Obsidian physics parameters.
"""
import asyncio
import datetime
import hashlib
import structlog
from pathlib import Path
import networkx as nx

from services.embedding_service import EmbeddingService
from services.llm_service import LLMService
from services.database import GraphNodeDB, GraphEdgeDB, get_db

log = structlog.get_logger(__name__)


class GraphService:
    def __init__(self, embedding_service: EmbeddingService, llm_service: LLMService, vault_service):
        self._embedding_svc = embedding_service
        self._llm_svc = llm_service
        self._vault_svc = vault_service
        self._graph = nx.Graph()
        self._nodes: dict[str, dict] = {}
        self._edges: list[dict] = []
        self._communities: dict[str, int] = {}
        self._community_meta: dict[int, dict] = {}

    async def initialize(self):
        """Load graph from database."""
        try:
            async with get_db() as db:
                nodes = await GraphNodeDB.get_all(db)
                edges = await GraphEdgeDB.get_all(db)

            for node in nodes:
                self._add_node_to_graph(node)
            for edge in edges:
                self._add_edge_to_graph(edge)

            if self._graph.number_of_nodes() > 0:
                await self._detect_communities()

            log.info(
                "Graph initialized",
                nodes=self._graph.number_of_nodes(),
                edges=self._graph.number_of_edges(),
            )
        except Exception as e:
            log.error(f"Graph initialization error: {e}")

    def _add_node_to_graph(self, node: dict):
        nid = node["id"]
        self._graph.add_node(nid, **node)
        self._nodes[nid] = node

    def _add_edge_to_graph(self, edge: dict):
        self._graph.add_edge(edge["source"], edge["target"], **edge)
        self._edges.append(edge)

    async def get_all(
        self, include_embeddings: bool = False, limit: int = 5000
    ) -> tuple[list[dict], list[dict], dict]:
        """Return all nodes and edges, optionally excluding embeddings for performance."""
        nodes_with_meta = []
        count = 0

        # Pre-calculate degrees for speed
        degrees = dict(self._graph.degree())

        for nid, data in self._nodes.items():
            if count >= limit:
                break
            community = self._communities.get(nid, 0)
            degree = degrees.get(nid, 0)

            node_data = {**data}
            if not include_embeddings:
                node_data.pop("embedding", None)

            # Sanitize for UTF-16 compatibility (Flutter)
            node_data["label"] = self._sanitize_string(node_data.get("label", ""))
            if "content" in node_data:
                node_data["content"] = self._sanitize_string(node_data["content"])

            # Truncate content for graph view to save memory
            if "content" in node_data and len(node_data["content"]) > 200:
                node_data["content"] = node_data["content"][:200] + "..."

            nodes_with_meta.append({
                **node_data,
                "id": nid,
                "community": community,
                "degree": degree,
            })
            count += 1

        # Limit edges too
        edges = []
        for e in self._edges[:limit*2]:
            edges.append({
                "source": e["source"],
                "target": e["target"],
                "type": self._sanitize_string(e.get("type", "direct")),
                "weight": e.get("weight", 1.0)
            })

        log.info(f"Graph response: {len(nodes_with_meta)} nodes, {len(edges)} edges, {len(self._community_meta)} communities")
        return nodes_with_meta, edges, list(self._community_meta.values())

    def _sanitize_string(self, s: str) -> str:
        """Ensure string is valid UTF-16 for Flutter."""
        if not isinstance(s, str):
            return str(s)
        # Remove unpaired surrogates and other non-UTF-16 characters
        return s.encode('utf-16', 'surrogatepass').decode('utf-16', 'ignore')

    async def search(self, query: str, limit: int = 20) -> list[dict]:
        """Semantic + keyword search over nodes."""
        if not self._nodes:
            return []

        results = []
        query_lower = query.lower()

        # Keyword search
        for nid, node in self._nodes.items():
            label_lower = node.get("label", "").lower()
            content_lower = node.get("content", "").lower()
            if query_lower in label_lower or query_lower in content_lower:
                results.append({**node, "score": 1.0})

        # Semantic search
        if self._embedding_svc.is_ready and len(results) < limit:
            query_emb = await self._embedding_svc.embed(query)
            candidate_embs = []
            candidate_ids = []
            for nid, node in self._nodes.items():
                emb = node.get("embedding")
                if emb:
                    candidate_embs.append(emb)
                    candidate_ids.append(nid)

            if candidate_embs:
                top_k = self._embedding_svc.top_k_similar(
                    query_emb, candidate_embs, k=limit
                )
                for idx, score in top_k:
                    if score > 0.5:
                        nid = candidate_ids[idx]
                        if nid not in {r["id"] for r in results}:
                            results.append({
                                **self._nodes[nid],
                                "score": score,
                            })

        return sorted(results, key=lambda x: x.get("score", 0), reverse=True)[:limit]

    async def ingest_file(self, file_path: str) -> dict:
        """Ingest a file into the knowledge graph."""
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        try:
            if path.is_dir():
                return await self._ingest_directory(path)
            else:
                return await self._ingest_single_file(path)
        except FileNotFoundError:
            raise
        except Exception as e:
            log.error(f"Ingest failed for {path.name}: {e}", exc_info=True)
            return {"nodes_created": 0, "error": str(e), "file": str(path)}

    async def _ingest_directory(self, dir_path: Path) -> dict:
        total, success, failed = 0, 0, 0
        supported = {".txt", ".md", ".py", ".js", ".ts", ".json",
                     ".html", ".css", ".pdf", ".docx", ".pptx", ".csv"}
        for file_path in dir_path.rglob("*"):
            if file_path.is_file() and file_path.suffix.lower() in supported:
                total += 1
                try:
                    await self._ingest_single_file(file_path, detect_communities=False)
                    success += 1
                except Exception as e:
                    failed += 1
                    log.warning(f"Failed to ingest {file_path}: {e}")

        if success > 0:
            await self._detect_communities()
            # Update Vault Map with ingestion summary
            summary = f"\n### Ingestion: {dir_path.name}\n- Date: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n- Files: {success}/{total}\n- Clusters: {len(self._community_meta)}\n"
            await self._update_vault_summary(summary)

        return {"total": total, "success": success, "failed": failed}

    async def _update_vault_summary(self, summary_text: str):
        """Append ingestion summary to the vault map."""
        try:
            map_note = await self._vault_svc.get_note("vault-map")
            if map_note:
                content = map_note["content"] + summary_text
                await self._vault_svc.update_note("vault-map", content=content)
        except Exception as e:
            log.warning(f"Failed to update vault map: {e}")

    async def _link_cross_ingestion(self, new_node_ids: list[str]):
        """
        Interconnect new nodes with existing nodes based on semantic similarity
        and label overlap to maintain updated context.
        """
        if not new_node_ids or self._graph.number_of_nodes() < 2:
            return

        log.info(f"Cross-linking {len(new_node_ids)} new nodes with existing graph...")
        
        # 1. Label overlap linking (Fast)
        existing_nodes = [nid for nid in self._nodes if nid not in new_node_ids]
        if not existing_nodes:
            return

        existing_labels = {self._nodes[nid]["label"].lower(): nid for nid in existing_nodes}

        edges_created = 0
        async with get_db() as db:
            for n_id in new_node_ids:
                n_data = self._nodes[n_id]
                n_label = n_data.get("label", "").lower()
                n_content = n_data.get("content", "").lower()

                # Check if existing labels appear in new content (wikilink style)
                for label, e_id in existing_labels.items():
                    if len(label) > 3 and label in n_content:
                        edge = {"source": n_id, "target": e_id, "type": "LINKED_TO", "weight": 0.8}
                        if not self._graph.has_edge(n_id, e_id):
                            await GraphEdgeDB.create(db, edge)
                            self._add_edge_to_graph(edge)
                            edges_created += 1

                # Check if new label appears in existing content
                for e_id in existing_nodes:
                    e_data = self._nodes[e_id]
                    e_content = e_data.get("content", "").lower()
                    if len(n_label) > 3 and n_label in e_content:
                        edge = {"source": e_id, "target": n_id, "type": "LINKED_TO", "weight": 0.8}
                        if not self._graph.has_edge(e_id, n_id):
                            await GraphEdgeDB.create(db, edge)
                            self._add_edge_to_graph(edge)
                            edges_created += 1

            # 2. Semantic Linking (High quality but slower)
            if self._embedding_svc.is_ready:
                new_embs = []
                valid_new_ids = []
                for nid in new_node_ids:
                    node = self._nodes[nid]
                    emb = node.get("embedding")
                    if emb:
                        new_embs.append(emb)
                        valid_new_ids.append(nid)
                
                if new_embs:
                    existing_embs = []
                    valid_ext_ids = []
                    for nid in existing_nodes:
                        node = self._nodes[nid]
                        emb = node.get("embedding")
                        if emb:
                            existing_embs.append(emb)
                            valid_ext_ids.append(nid)
                    
                    if existing_embs:
                        # For each new node, find top similar existing nodes
                        for i, n_emb in enumerate(new_embs):
                            top_k = self._embedding_svc.top_k_similar(n_emb, existing_embs, k=3)
                            for idx, score in top_k:
                                if score > 0.82: # High threshold for automatic semantic linking
                                    e_id = valid_ext_ids[idx]
                                    n_id = valid_new_ids[i]
                                    edge = {"source": n_id, "target": e_id, "type": "SEMANTIC_SIMILAR", "weight": score}
                                    if not self._graph.has_edge(n_id, e_id):
                                        await GraphEdgeDB.create(db, edge)
                                        self._add_edge_to_graph(edge)
                                        edges_created += 1

        log.info(f"Cross-ingestion linking complete: {edges_created} new edges created.")

    async def _ingest_single_file(self, file_path: Path, detect_communities: bool = True) -> dict:
        """Extract text, chunk, embed, and add to graph via Vault Notes."""
        content = await self._extract_text(file_path)
        if not content.strip():
            return {"nodes_created": 0}

        chunks = self._chunk_text(content, chunk_size=2000, overlap=200)
        all_new_node_ids = []
        nodes_created = 0
        edges_created = 0

        for i, chunk in enumerate(chunks):
            # 1. Extract Triplets via LLM
            triplets = await self._extract_triplets(chunk)

            # 2. Build Markdown content with Wikilinks
            links = set()
            keywords = []
            
            # Create Chunk Node
            base_title = self._extract_title(chunk, file_path)
            note_title = f"{base_title} (Chunk {i})"
            chunk_id = hashlib.md5(f"{file_path}_{i}".encode()).hexdigest()[:12]
            
            chunk_node = {
                "id": chunk_id,
                "label": note_title,
                "content": chunk,
                "content_type": "knowledge_chunk",
                "source": str(file_path),
                "chunk_index": i,
            }
            
            async with get_db() as db:
                await GraphNodeDB.create(db, chunk_node)
            self._add_node_to_graph(chunk_node)
            all_new_node_ids.append(chunk_id)
            nodes_created += 1
            
            # Real-time linking for the new chunk node
            await self._link_cross_ingestion([chunk_id])

            # Process Triplets
            node_lookup = {n["label"].lower(): nid for nid, n in self._nodes.items()}

            for entity in triplets.get("entities", []):
                label = entity.get("label", "").strip()
                if label:
                    norm_label = label.lower()
                    links.add(f"[[{label}]]")
                    keywords.append(label)
                    
                    ent_id = node_lookup.get(norm_label)
                    if not ent_id:
                        ent_id = hashlib.md5(norm_label.encode()).hexdigest()[:12]
                        ent_node = {
                            "id": ent_id,
                            "label": label,
                            "content_type": entity.get("type", "concept"),
                            "source": str(file_path),
                        }
                        async with get_db() as db:
                            await GraphNodeDB.create(db, ent_node)
                        self._add_node_to_graph(ent_node)
                        all_new_node_ids.append(ent_id)
                        node_lookup[norm_label] = ent_id
                        nodes_created += 1
                        
                        # Real-time linking for the new entity node
                        await self._link_cross_ingestion([ent_id])
                        
                        await self._vault_svc.create_note(
                            title=label,
                            content=f"# {label}\n\nType: {entity.get('type', 'concept')}\n\nExtracted from [[{note_title}]]",
                            folder="atlas",
                            tags=["entity", entity.get("type", "concept")]
                        )
                    
                    edge = {"source": chunk_id, "target": ent_id, "type": "CONTAINS"}
                    log.debug(f"Linking {chunk_id} to {ent_id}: CONTAINS")
                    async with get_db() as db:
                        await GraphEdgeDB.create(db, edge)
                    self._add_edge_to_graph(edge)
                    edges_created += 1

            for rel in triplets.get("relationships", []):
                s_label = rel.get("source", "").strip()
                t_label = rel.get("target", "").strip()
                if s_label and t_label:
                    s_norm, t_norm = s_label.lower(), t_label.lower()
                    
                    s_id = node_lookup.get(s_norm) or hashlib.md5(s_norm.encode()).hexdigest()[:12]
                    t_id = node_lookup.get(t_norm) or hashlib.md5(t_norm.encode()).hexdigest()[:12]
                    
                    for lbl, rid in [(s_label, s_id), (t_label, t_id)]:
                        if rid not in self._nodes:
                            n = {"id": rid, "label": lbl, "content_type": "entity", "source": str(file_path)}
                            async with get_db() as db:
                                await GraphNodeDB.create(db, n)
                            self._add_node_to_graph(n)
                            all_new_node_ids.append(rid)
                            node_lookup[lbl.lower()] = rid
                            nodes_created += 1
                            
                            # Real-time linking
                            await self._link_cross_ingestion([rid])
                            await self._vault_svc.create_note(title=lbl, content=f"# {lbl}\n\nType: entity\n\nReferenced in [[{note_title}]]", folder="atlas", tags=["entity"])
                    
                    edge = {"source": s_id, "target": t_id, "type": rel.get("type", "LINKED_TO"), "weight": rel.get("weight", 1.0)}
                    log.debug(f"Linking {s_id} to {t_id}: {edge['type']}")
                    async with get_db() as db:
                        await GraphEdgeDB.create(db, edge)
                    self._add_edge_to_graph(edge)
                    edges_created += 1

            created_at = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            md_content = f"""---
chunk_id: {chunk_id}
source: {file_path.name}
page: {i}
title: {note_title}
keywords: {keywords}
created: {created_at}
tree_path: {file_path.parent.name} > Page {i} > {base_title[:50]}
---

{chunk}

"""
            if links:
                md_content += "### Related Concepts\n"
                for link in links:
                    md_content += f"- {link}\n"

            await self._vault_svc.create_note(
                title=note_title,
                content=md_content,
                folder="atlas",
                tags=["ingested", "chunk"],
                note_type="knowledge_chunk"
            )

        # 3. Perform Cross-Ingestion Linking
        await self._link_cross_ingestion(all_new_node_ids)

        if detect_communities:
            await self._detect_communities()

        return {"nodes_created": nodes_created, "edges_created": edges_created, "file": str(file_path)}

    async def _extract_text(self, file_path: Path) -> str:
        """Extract text from various file types — delegates to text_extractor utility."""
        from services.utils.text_extractor import extract_text as _ext
        try:
            return await _ext(file_path)
        except Exception as e:
            log.warning(f"Text extraction failed for {file_path.name}: {e}")
            return ""

    def _chunk_text(self, text: str, chunk_size: int = 512,
                    overlap: int = 64) -> list[str]:
        """Split text into overlapping chunks."""
        words = text.split()
        if not words:
            return []
        chunks, start = [], 0
        while start < len(words):
            end = min(start + chunk_size, len(words))
            chunks.append(" ".join(words[start:end]))
            start += chunk_size - overlap
        return chunks

    def _extract_title(self, content: str, file_path: Path) -> str:
        lines = content.strip().split("\n")
        for line in lines:
            stripped = line.strip().lstrip("#").strip()
            if len(stripped) > 3:
                return stripped[:60]
        return file_path.stem[:60]

    def _get_content_type(self, suffix: str) -> str:
        mapping = {
            ".py": "code", ".js": "code", ".ts": "code",
            ".md": "markdown", ".pdf": "document",
            ".docx": "document", ".json": "data", ".csv": "data",
        }
        return mapping.get(suffix.lower(), "text")

    async def _extract_triplets(self, text: str) -> dict:
        """Use LLM to extract entities and relations in JSON format."""
        if not self._llm_svc.is_ready:
            return {"entities": [], "relationships": []}

        prompt = f"""
Extract key entities and their semantic relationships from the text below.
Focus on: (Entity A) -> [Relationship] -> (Entity B).
Keep entity labels short (1-3 words).

Use these specific relationship types:
- LINKED_TO (direct wikilink or reference)
- REFERENCED_BY (backlink or citation)
- SEMANTIC_SIMILAR (concepts in similar context)
- INFERRED (logically deduced connection)

Return ONLY valid JSON in this format:
{{
  "entities": [{{ "label": "Entity Name", "type": "person/org/concept/entity/file" }}],
  "relationships": [
    {{ "source": "Entity A", "target": "Entity B",
       "type": "LINKED_TO/INFERRED/...", "weight": 1.0 }}
  ]
}}

TEXT:
{text[:2000]}
"""
        try:
            response = await self._llm_svc.complete(
                prompt, temperature=0.1, max_tokens=1000
            )
            # Find JSON block
            import yaml
            import re
            match = re.search(r"\{.*\}", response, re.DOTALL)
            if match:
                try:
                    # Basic JSON repair for truncated arrays
                    json_str = match.group(0)
                    if json_str.count("[") > json_str.count("]"):
                        json_str += "]}"
                    elif json_str.count("{") > json_str.count("}"):
                        json_str += "}"
                    return yaml.safe_load(json_str) or {"entities": [], "relationships": []}
                except yaml.YAMLError:
                    return {"entities": [], "relationships": []}
        except Exception as e:
            log.warning(f"LLM triplet extraction failed: {e}")

        return {"entities": [], "relationships": []}

    async def _detect_communities(self):
        """Leiden/Louvain community detection."""
        if self._graph.number_of_nodes() < 2:
            return

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._run_community_detection)
        await self._analyze_communities()

    def _run_community_detection(self):
        try:
            import community as community_louvain
            partition = community_louvain.best_partition(self._graph)
            self._communities = partition
        except ImportError:
            for i, component in enumerate(
                nx.connected_components(self._graph)
            ):
                for node in component:
                    self._communities[node] = i

    async def _analyze_communities(self):
        """Generate semantic names and summaries for communities."""
        if not self._llm_svc.is_ready or not self._communities:
            return

        groups: dict[int, list[str]] = {}
        for nid, cid in self._communities.items():
            if cid not in groups:
                groups[cid] = []
            groups[cid].append(self._nodes[nid].get("label", ""))

        for cid, labels in groups.items():
            if cid in self._community_meta:
                continue

            context = ", ".join(labels[:40])
            prompt = f"Analyze these knowledge graph entities from a cluster: {context}. " \
                     "Identify the core theme. " \
                     "Provide a professional, contextual 2-4 word 'name' and 1-sentence 'summary'. " \
                     "Do NOT use 'Cluster X' or generic names. " \
                     "Return ONLY valid JSON: {\"name\": \"...\", \"summary\": \"...\"}"
            try:
                res = await self._llm_svc.complete(prompt, temperature=0.1)
                import json
                import re
                match = re.search(r"\{.*\}", res, re.DOTALL)
                if match:
                    self._community_meta[cid] = json.loads(match.group(0))
            except Exception:
                continue

    async def clear_graph(self, keep_initial: bool = False):
        """Delete nodes and edges from memory and database."""
        async with get_db() as db:
            from sqlalchemy import delete
            from services.database import GraphNodeORM, GraphEdgeORM
            
            if keep_initial:
                # Keep nodes that have no source or specific internal source
                # For now, let's say keep nodes where source is empty
                await db.execute(delete(GraphEdgeORM).where(GraphEdgeORM.edge_type != "CORE"))
                await db.execute(delete(GraphNodeORM).where(GraphNodeORM.source != ""))
            else:
                await GraphNodeDB.delete_all(db)
                await GraphEdgeDB.delete_all(db)
            
            if not keep_initial:
                # Also clear extracted entity notes from the vault for a truly clean slate
                atlas_path = Path(self._vault_svc._root) / "ACE" / "Atlas"
                if atlas_path.exists():
                    import shutil
                    for item in atlas_path.iterdir():
                        if item.is_file() and item.suffix == ".md":
                            item.unlink()
                # Refresh vault cache
                await self._vault_svc.initialize()
        
        # Reload from DB to sync memory
        self._graph.clear()
        self._nodes.clear()
        self._edges.clear()
        self._communities.clear()
        self._community_meta.clear()
        await self.initialize()
        log.info("Knowledge graph cleared", keep_initial=keep_initial)
