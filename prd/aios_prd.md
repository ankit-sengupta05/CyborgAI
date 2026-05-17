# 📋 Product Requirements Document (PRD) - v4.0
## AI OS: Real-Time Synced Agentic Local-First RAG-Powered Multimodal Markdown Knowledge System

**Document Version:** 4.0 (Real-Time Sync Architecture)  
**Target Platform:** Flutter (Android + Windows)  
**Language:** Dart (100%)  
**Execution:** Fully Local / Offline-First / Agentic / RAG-Native / Event-Driven Sync  
**Generated For:** Claude Project Generation  

---

## 🎯 Executive Summary

Build a **local-first, agentic AI OS with native RAG architecture and real-time bidirectional synchronization** that synthesizes Nick Milo's "File Over AI" philosophy [[video transcript]] with Chase AI's Agentic OS workflow [[video transcript]]. The system automatically syncs AI OS system files (`.ai_os/`, `AI_OS/`, `Memory/`) with all vault content, chat history, multimodal ingestion, skill executions, and knowledge graph updates—in real-time, event-driven, and fully local. Every change propagates intelligently: a chat message updates the graph, which triggers re-ranking weights, which updates skill context, which reflects in the UI—all without user intervention.

> **Core Philosophy:** "File Over AI + Live Sync + Agentic Autonomy" — Your `.md` files are the source of truth. The system self-organizes. Changes ripple intelligently. Everything stays on-device.

---

## 🧭 Core Principles (Sync-Enhanced)

| Principle | Sync Implementation |
|-----------|-------------------|
| **File Over AI** | All sync operations mutate plain `.md` files; no hidden databases; sync state stored as `.sync.json` sidecars |
| **Event-Driven Architecture** | Every user action, file change, or AI operation emits a typed event; subscribers react autonomously |
| **Bidirectional Sync** | System files ↔ user content ↔ graph ↔ vector index ↔ chat history: all update each other intelligently |
| **Incremental & Efficient** | SHA256 diffing + content-aware chunking + dependency graphs ensure only affected components re-process |
| **Provenance-First Sync** | Every sync operation logged with: trigger event, affected files, timestamp, confidence, rollback capability |
| **Conflict Resolution** | Last-write-wins with user override; merge strategies for structured data; audit trail for manual review |
| **Observability by Default** | Real-time sync dashboard shows: event flow, propagation latency, conflicts resolved, system health |
| **User-Controlled Autonomy** | Toggle per-feature: "Auto-sync graph", "Auto-update skills", "Auto-embed new content"; defaults to ON |

---

## 🗂️ Directory & File System Architecture (Sync-Optimized)

```
vault_root/
├── .ai_os/                          # System Runtime + Sync Engine
│   ├── config.json                  # Global settings + sync preferences
│   ├── sync_config.yaml             # Sync rules: triggers, throttles, conflict policies
│   ├── agent.md                     # Portable agent instructions (sync-aware)
│   ├── event_bus/                   # Local event log (append-only)
│   │   ├── events.jsonl             # Typed events: FileChanged, ChatMessage, SkillExecuted
│   │   ├── subscriptions.json       # Which services listen to which events
│   │   └── replay_checkpoint.txt    # Last processed event ID for crash recovery
│   ├── sync_state/                  # Real-time sync tracking
│   │   ├── file_hashes.sqlite       # path → SHA256 + last_modified + sync_status
│   │   ├── dependency_graph.json    # Which files depend on which (for cascade updates)
│   │   ├── pending_syncs.json       # Queue of pending sync operations with priorities
│   │   └── sync_history.log         # Audit trail: event → actions → results
│   ├── embedding_models/            # Local embedding models (synced with model registry)
│   ├── vector_index/                # On-device vector storage (with sync metadata)
│   │   ├── chunks_index.bin
│   │   ├── chunk_metadata.sqlite    # Includes: sync_version, last_updated_by_event
│   │   └── index_sync_state.json    # Index rebuild triggers + incremental update log
│   ├── graph_state/                 # Live-synced knowledge graph
│   │   ├── graph.json               # Nodes/edges with sync_version + event_source
│   │   ├── node_embeddings.cache    # With cache invalidation triggers
│   │   ├── traversal_cache/
│   │   └── graph_sync_log.jsonl     # Graph mutation events with provenance
│   ├── conversation_log/            # Chat sessions with sync provenance
│   │   ├── sessions/
│   │   ├── retrieval_audit.log
│   │   └── chat_graph_sync.log      # Which chat messages triggered which graph updates
│   ├── skill_registry.json          # Skills with auto-update triggers + sync dependencies
│   ├── observability/               # Sync performance + system health
│   │   ├── sync_metrics.json        # Latency, throughput, conflict rate per event type
│   │   ├── cascade_depth_stats.json # How far do updates propagate on average?
│   │   └── health_dashboard.json    # Real-time system health scores
│   └── automation_queue/            # Sync-triggered automation jobs
│
├── ACE/                             # Core Knowledge (Sync Sources & Targets)
│   ├── Atlas/
│   │   ├── Concepts/
│   │   │   ├── machine_learning.md
│   │   │   ├── machine_learning.md.sync.json  # Auto-generated: last_sync_event, dependencies
│   │   │   └── _index.md
│   │   ├── Domains/
│   │   └── _index.md.sync.json      # Domain centroid updates trigger re-embedding
│   ├── Calendar/
│   │   └── 2026/04-April/2026-04-29.md.sync.json
│   └── Efforts/
│       └── Project_Alpha/brief.md.sync.json
│
├── AI_OS/                           # Maps Layer + Auto-Syncing System Files
│   ├── me.md                        # User identity → auto-updated from chat patterns, preferences
│   ├── me.md.sync.json              # Tracks: last_updated_by, change_source, confidence
│   ├── vault_map.md                 # Navigation manual → auto-updated when new domains/folders added
│   ├── skills/
│   │   ├── research/deep_research.md
│   │   ├── research/deep_research.md.sync.json  # Auto-updates when retrieval performance changes
│   │   └── _index.md.sync.json      # Skill registry auto-syncs with execution metrics
│   ├── rag_prompts/
│   │   ├── chat_context.md.sync.json  # Prompt templates versioned + A/B tested via sync
│   │   └── _index.md
│   ├── auto_config/                 # Auto-generated config updates
│   │   ├── retrieval_weights.json   # Auto-tuned based on observability feedback
│   │   ├── chunking_rules.json      # Updated when new content types detected
│   │   └── sync_triggers.yaml       # Dynamic sync rules learned from usage patterns
│   └── _index.md.sync.json
│
├── Memory/                          # Carpathy RAG Pattern: Raw → Wiki → Output (Sync Pipeline)
│   ├── Raw/
│   │   ├── ingestion/image_abc123.md
│   │   ├── ingestion/image_abc123.md.sync.json  # Tracks: OCR confidence → graph update → skill trigger
│   │   ├── conversations/chat_session_xyz.md
│   │   └── _index.md.sync.json      # Raw folder centroid updates trigger Wiki synthesis
│   ├── Wiki/
│   │   ├── concepts/machine_learning.md
│   │   ├── concepts/machine_learning.md.sync.json  # Auto-linked from Raw + chat + graph inference
│   │   └── _index.md.sync.json
│   └── Output/
│       └── briefings/daily_brief_2026-04-29.md.sync.json
│
├── Inbox/                           # Ingestion Entry Point (Sync Trigger Hub)
│   ├── images/ ├── videos/ ├── audio/ ├── documents/
│   └── _process_queue.md.sync.json  # Live sync status: ingestion → chunking → embedding → graph → skills
│
├── chunks/                          # First-Class Chunk Storage (Sync-Aware)
│   ├── by_file/
│   ├── by_embedding/
│   ├── chunk_registry.sqlite        # Includes: sync_version, last_updated_event_id
│   └── _sync_manifest.json          # Master sync state for all chunks
│
├── _sync_ignore                     # Files/folders excluded from auto-sync (like .gitignore)
│
└── _graphify_ignore                 # Exclude patterns for graph building
```

### Sync Metadata File Format (`.sync.json`)
```json
{
  "source_file": "ACE/Atlas/Concepts/machine_learning.md",
  "sync_version": 42,
  "last_updated": "2026-04-29T14:32:18Z",
  "updated_by_event": {
    "event_id": "evt_chat_entity_extract_789",
    "event_type": "ChatEntityExtracted",
    "timestamp": "2026-04-29T14:32:17Z"
  },
  "dependencies": [
    "AI_OS/rag_prompts/chat_context.md",
    ".ai_os/vector_index/chunk_metadata.sqlite",
    ".ai_os/graph_state/graph.json"
  ],
  "downstream_effects": [
    "skill:deep_research context updated",
    "graph node centrality recalculated",
    "embedding cache invalidated"
  ],
  "provenance": {
    "change_type": "content_append",
    "confidence": 0.96,
    "extraction_method": "LLM_ENTITY_EXTRACTION",
    "user_override": false
  },
  "rollback": {
    "previous_version": 41,
    "backup_path": ".ai_os/sync_state/backups/machine_learning.md.v41",
    "can_rollback": true
  }
}
```

---

## 🔄 Real-Time Sync Architecture: Event-Driven Cascade System

### High-Level Sync Flow
```mermaid
graph LR
    A[User Action / External Event] --> B[Event Bus: Publish Typed Event]
    B --> C[Sync Orchestrator: Route to Subscribers]
    
    subgraph C [Sync Orchestrator]
        C1[FileWatcher] --> C5[Dependency Resolver]
        C2[ChatListener] --> C5
        C3[IngestionComplete] --> C5
        C4[SkillExecuted] --> C5
        C5 --> C6[Priority Queue]
    end
    
    C6 --> D[Sync Handlers: Parallel Execution]
    
    subgraph D [Sync Handlers]
        D1[Graph Sync Handler] --> D7[Provenance Logger]
        D2[Vector Index Handler] --> D7
        D3[Skill Context Handler] --> D7
        D4[Config Auto-Update Handler] --> D7
        D5[UI State Handler] --> D7
        D6[Observability Handler] --> D7
    end
    
    D7 --> E[Sync Complete: Emit SyncFinished Event]
    E --> F[UI Refresh + User Notification (if needed)]
    
    style C fill:#e3f2fd
    style D fill:#e8f5e9
    style E fill:#fff3e0
```

### Event Taxonomy (Typed Sync Triggers)
```dart
// Core event types that trigger sync cascades
abstract class SyncEvent {
  String eventId; // UUID
  DateTime timestamp;
  String source; // 'user', 'chat', 'ingestion', 'skill', 'system'
  SyncPriority priority; // IMMEDIATE, HIGH, NORMAL, LOW, BACKGROUND
  Map<String, dynamic> payload;
}

class FileChangedEvent extends SyncEvent {
  String filePath;
  FileChangeType changeType; // CREATED, MODIFIED, DELETED, RENAMED
  String previousHash; // For diffing
  String currentHash;
  List<String> affectedChunks; // Pre-computed for efficiency
}

class ChatMessageEvent extends SyncEvent {
  String sessionId;
  ChatTurn turn;
  List<String> retrievedChunkIds; // For provenance chaining
  List<String> extractedEntities; // For graph updates
  bool requiresGraphUpdate;
}

class IngestionCompleteEvent extends SyncEvent {
  String sourceFile;
  IngestionResult result;
  List<RAGChunk> generatedChunks;
  bool triggerWikiSynthesis; // Auto Raw→Wiki pipeline
}

class SkillExecutedEvent extends SyncEvent {
  String skillId;
  SkillResult result;
  List<String> retrievedContextIds;
  String outputFilePath;
  bool updateSkillMetrics; // Trigger auto-optimization
}

class GraphMutatedEvent extends SyncEvent {
  List<String> addedNodes;
  List<String> updatedNodes;
  List<String> addedEdges;
  GraphChangeReason reason; // CHAT_DERIVED, INFERRED, USER_EDIT, SKILL_EXECUTED
  bool triggerReEmbedding; // If structure changed significantly
}

class ConfigAutoUpdateEvent extends SyncEvent {
  String configPath; // e.g., '.ai_os/auto_config/retrieval_weights.json'
  Map<String, dynamic> previousValues;
  Map<String, dynamic> newValues;
  String optimizationReason; // 'improved_precision', 'user_feedback', 'performance'
  bool requiresUserApproval; // For sensitive changes
}
```

### Sync Orchestrator: Intelligent Cascade Resolution
```dart
class SyncOrchestrator {
  final EventBus _eventBus;
  final DependencyGraph _dependencyGraph;
  final PrioritySyncQueue _syncQueue;
  final Map<EventType, List<SyncHandler>> _subscribers;
  
  // Register a handler for specific event types
  void subscribe({
    required List<EventType> eventTypes,
    required SyncHandler handler,
    SyncPriority defaultPriority = SyncPriority.NORMAL,
  }) {
    for (final type in eventTypes) {
      _subscribers[type] ??= [];
      _subscribers[type]!.add(handler);
    }
  }
  
  // Process incoming event: route, prioritize, execute
  Future<void> handleEvent(SyncEvent event) async {
    // 1. Log event to append-only log (crash recovery)
    await _eventBus.persist(event);
    
    // 2. Resolve dependency cascade: which files/components need updating?
    final affectedComponents = await _dependencyGraph.resolveCascade(
      sourceEvent: event,
      maxDepth: 3, // Prevent infinite loops
    );
    
    // 3. Prioritize sync operations
    final syncTasks = affectedComponents.map((component) => SyncTask(
      component: component,
      priority: _calculatePriority(event, component),
      estimatedDuration: component.estimatedSyncTime,
    )).toList();
    
    // 4. Execute in priority order with concurrency limits
    await _syncQueue.executeBatch(
      tasks: syncTasks,
      maxConcurrent: _platformSyncConcurrency, // 2 on Android, 4 on Windows
      onError: _handleSyncError,
      onComplete: _emitSyncFinished,
    );
    
    // 5. Update dependency graph with new relationships discovered during sync
    await _dependencyGraph.updateFromSyncResults(syncTasks);
  }
  
  // Smart priority calculation
  SyncPriority _calculatePriority(SyncEvent event, SyncComponent component) {
    // User-facing components get higher priority
    if (component.affectsUI) return SyncPriority.HIGH;
    
    // Chat-related syncs are time-sensitive
    if (event is ChatMessageEvent) return SyncPriority.IMMEDIATE;
    
    // Background indexing can be deferred
    if (component.isBackgroundOnly) return SyncPriority.LOW;
    
    // Default to event's priority
    return event.priority;
  }
}
```

### Dependency Graph: Mapping Sync Cascades
```dart
class DependencyGraph {
  // Node = file/component; Edge = "A depends on B" or "A affects B"
  final Map<String, SyncNode> _nodes = {};
  final Map<String, Set<String>> _outgoingEdges = {}; // A → [B, C] = A affects B, C
  final Map<String, Set<String>> _incomingEdges = {}; // A ← [B, C] = B, C affect A
  
  // Register a file/component with its sync metadata
  void registerNode({
    required String nodeId, // Usually file path
    required SyncNodeMetadata metadata,
    List<String>? affects, // Downstream dependencies
    List<String>? affectedBy, // Upstream dependencies
  }) {
    _nodes[nodeId] = SyncNode(metadata: metadata);
    
    if (affects != null) {
      for (final target in affects) {
        _outgoingEdges[nodeId] ??= {};
        _outgoingEdges[nodeId]!.add(target);
        _incomingEdges[target] ??= {};
        _incomingEdges[target]!.add(nodeId);
      }
    }
  }
  
  // Resolve cascade: given an event source, which components need updating?
  Future<List<SyncComponent>> resolveCascade({
    required SyncEvent sourceEvent,
    required int maxDepth,
  }) async {
    final visited = <String>{};
    final toProcess = <String>[sourceEvent.source];
    final affected = <SyncComponent>[];
    
    int depth = 0;
    while (toProcess.isNotEmpty && depth < maxDepth) {
      final current = toProcess.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);
      
      final node = _nodes[current];
      if (node != null && _shouldSync(node, sourceEvent)) {
        affected.add(SyncComponent(
          nodeId: current,
          metadata: node.metadata,
          syncHandler: _selectHandler(node, sourceEvent),
        ));
      }
      
      // Add downstream dependencies to queue
      final downstream = _outgoingEdges[current] ?? {};
      for (final target in downstream) {
        if (!visited.contains(target)) {
          toProcess.add(target);
        }
      }
      
      depth++;
    }
    
    // Sort by priority + estimated duration for efficient batching
    affected.sort((a, b) => 
      a.metadata.priority.index.compareTo(b.metadata.priority.index)
    );
    
    return affected;
  }
  
  // Smart sync decision: does this component actually need updating?
  bool _shouldSync(SyncNode node, SyncEvent event) {
    // Check if event type matches component's interests
    if (!node.metadata.listensTo.contains(event.runtimeType)) {
      return false;
    }
    
    // Check content-based conditions
    if (node.metadata.condition != null) {
      return node.metadata.condition!(event);
    }
    
    return true;
  }
}
```

---

## 🧩 Sync Handlers: Specialized Real-Time Updaters

### 1. Graph Sync Handler (Live Knowledge Graph Updates)
```dart
class GraphSyncHandler implements SyncHandler {
  @override
  List<Type> get subscribedEvents => [
    FileChangedEvent,
    ChatMessageEvent,
    IngestionCompleteEvent,
    SkillExecutedEvent,
  ];
  
  @override
  Future<SyncResult> execute(SyncEvent event, SyncContext context) async {
    final mutations = <GraphMutation>[];
    
    if (event is ChatMessageEvent && event.extractedEntities.isNotEmpty) {
      // Create/update nodes for extracted entities
      for (final entity in event.extractedEntities) {
        mutations.add(GraphMutation.upsertNode(
          id: _generateEntityNodeId(entity),
          type: NodeType.CHAT_ENTITY,
          properties: {
            'name': entity.name,
            'type': entity.type,
            'source_session': event.sessionId,
            'confidence': entity.confidence,
          },
          edges: [
            // Link to retrieved chunks that mentioned this entity
            for (final chunkId in event.retrievedChunkIds)
              GraphEdge(
                type: EdgeType.CHAT_DERIVED,
                target: chunkId,
                confidence: 0.9,
              ),
          ],
        ));
      }
    }
    
    if (event is FileChangedEvent) {
      // Update node for changed file; re-extract relationships
      mutations.add(GraphMutation.updateNode(
        id: _fileToNodeId(event.filePath),
        properties: {
          'last_modified': event.timestamp,
          'content_hash': event.currentHash,
        },
        triggerRelationshipInference: true,
      ));
    }
    
    if (mutations.isEmpty) return SyncResult.noOp();
    
    // Apply mutations atomically
    final result = await _graphService.applyMutationsBatch(mutations);
    
    // If graph structure changed significantly, trigger re-embedding
    if (result.structureChangedSignificantly) {
      context.enqueueSyncEvent(GraphMutatedEvent(
        addedNodes: result.addedNodeIds,
        updatedNodes: result.updatedNodeIds,
        addedEdges: result.addedEdgeIds,
        reason: GraphChangeReason.fromEvent(event),
        triggerReEmbedding: true,
      ));
    }
    
    return SyncResult.success(
      affectedComponents: ['knowledge_graph'],
      downstreamTriggers: result.structureChangedSignificantly 
        ? ['vector_index_reembed'] 
        : [],
    );
  }
}
```

### 2. Vector Index Sync Handler (Incremental Embedding Updates)
```dart
class VectorIndexSyncHandler implements SyncHandler {
  @override
  List<Type> get subscribedEvents => [
    IngestionCompleteEvent,
    FileChangedEvent,
    GraphMutatedEvent, // When structure changes, re-embed affected nodes
    ConfigAutoUpdateEvent, // If embedding model changed
  ];
  
  @override
  Future<SyncResult> execute(SyncEvent event, SyncContext context) async {
    final chunksToUpdate = <RAGChunk>[];
    
    if (event is IngestionCompleteEvent) {
      // New chunks from ingestion: embed and add to index
      chunksToUpdate.addAll(event.generatedChunks);
    }
    
    if (event is FileChangedEvent && event.changeType != FileChangeType.DELETED) {
      // Re-embed changed file's chunks
      final affectedChunks = await _chunkService.getChunksForFile(
        event.filePath,
        includeUnchanged: false, // Only re-embed if content changed
      );
      chunksToUpdate.addAll(affectedChunks);
    }
    
    if (event is GraphMutatedEvent && event.triggerReEmbedding) {
      // Re-embed nodes whose relationships changed significantly
      final affectedNodeIds = {...event.addedNodes, ...event.updatedNodes};
      final nodeChunks = await _chunkService.getChunksForNodes(affectedNodeIds);
      chunksToUpdate.addAll(nodeChunks);
    }
    
    if (chunksToUpdate.isEmpty) return SyncResult.noOp();
    
    // Batch embed with progress tracking
    final embeddings = await _embeddingService.batchEmbedWithProgress(
      chunks: chunksToUpdate,
      onProgress: (progress) => context.reportProgress(progress),
    );
    
    // Incrementally update vector index (no full rebuild)
    final indexUpdateResult = await _vectorIndexService.incrementalUpdate(
      additions: embeddings.where((e) => e.operation == EmbeddingOp.ADD),
      updates: embeddings.where((e) => e.operation == EmbeddingOp.UPDATE),
      deletions: event is FileChangedEvent && event.changeType == FileChangeType.DELETED
        ? [event.filePath] 
        : [],
    );
    
    // Log index health metrics
    await _observabilityService.logVectorIndexUpdate(
      chunksProcessed: chunksToUpdate.length,
      indexSize: indexUpdateResult.newIndexSize,
      updateLatency: indexUpdateResult.duration,
    );
    
    return SyncResult.success(
      affectedComponents: ['vector_index'],
      metrics: {
        'chunks_embedded': chunksToUpdate.length,
        'index_size_mb': indexUpdateResult.newIndexSizeMB,
        'latency_ms': indexUpdateResult.duration.inMilliseconds,
      },
    );
  }
}
```

### 3. Skill Context Sync Handler (Auto-Update Skill Retrieval Configs)
```dart
class SkillContextSyncHandler implements SyncHandler {
  @override
  List<Type> get subscribedEvents => [
    SkillExecutedEvent,
    GraphMutatedEvent, // New relationships might improve skill context
    ConfigAutoUpdateEvent, // Global retrieval weight changes
  ];
  
  @override
  Future<SyncResult> execute(SyncEvent event, SyncContext context) async {
    final skillsToUpdate = <SkillSpec>[];
    
    if (event is SkillExecutedEvent && event.updateSkillMetrics) {
      // Analyze execution result: was retrieval effective?
      final metrics = await _observabilityService.getSkillRetrievalMetrics(
        skillId: event.skillId,
        timeWindow: Duration(days: 7),
      );
      
      if (metrics.precisionBelowThreshold || metrics.latencyTooHigh) {
        // Fetch skill spec and suggest config updates
        final skill = await _skillService.getSkill(event.skillId);
        final suggestedConfig = await _ragOptimizer.suggestSkillConfigUpdate(
          skill: skill,
          metrics: metrics,
        );
        
        if (suggestedConfig.requiresUserApproval) {
          // Queue for user review in observability dashboard
          context.enqueueUserNotification(SkillOptimizationSuggestion(
            skillId: skill.id,
            currentConfig: skill.ragConfig,
            suggestedConfig: suggestedConfig.newConfig,
            expectedImprovement: suggestedConfig.expectedImpact,
          ));
        } else {
          // Auto-apply safe optimizations
          await _skillService.updateSkillConfig(
            skillId: skill.id,
            newConfig: suggestedConfig.newConfig,
            reason: 'auto_optimization:${suggestedConfig.reason}',
          );
          skillsToUpdate.add(skill.copyWith(ragConfig: suggestedConfig.newConfig));
        }
      }
    }
    
    if (event is GraphMutatedEvent) {
      // Check if new graph relationships improve context for any skills
      final affectedSkills = await _skillService.findSkillsAffectedByGraphChanges(
        addedNodes: event.addedNodes,
        addedEdges: event.addedEdges,
      );
      
      for (final skill in affectedSkills) {
        // Re-evaluate retrieval scope: maybe new domain should be included
        final updatedScope = await _contextOptimizer.recommendScopeUpdate(
          skill: skill,
          newGraphContext: event,
        );
        
        if (updatedScope != skill.ragConfig.retrievalScope) {
          skillsToUpdate.add(skill.copyWith(
            ragConfig: skill.ragConfig.copyWith(retrievalScope: updatedScope),
          ));
        }
      }
    }
    
    if (skillsToUpdate.isEmpty) return SyncResult.noOp();
    
    // Apply updates with provenance
    for (final skill in skillsToUpdate) {
      await _skillService.persistSkillUpdate(
        skill: skill,
        syncEvent: event,
        autoApplied: true,
      );
    }
    
    return SyncResult.success(
      affectedComponents: skillsToUpdate.map((s) => 'skill:${s.id}').toList(),
      downstreamTriggers: ['ui_skill_list_refresh'],
    );
  }
}
```

### 4. Config Auto-Update Handler (Self-Optimizing System)
```dart
class ConfigAutoUpdateHandler implements SyncHandler {
  @override
  List<Type> get subscribedEvents => [
    ObservabilityMetricsUpdatedEvent,
    SkillExecutedEvent,
    ChatSessionCompletedEvent,
  ];
  
  @override
  Future<SyncResult> execute(SyncEvent event, SyncContext context) async {
    final configUpdates = <ConfigUpdate>[];
    
    // Example: Auto-tune retrieval weights based on precision feedback
    if (event is ObservabilityMetricsUpdatedEvent) {
      final metrics = event.metrics;
      
      if (metrics.retrievalPrecisionTrend == Trend.DECLINING) {
        // Analyze which retrieval method is underperforming
        final methodPerformance = await _ragAnalyzer.diagnoseRetrievalPerformance(
          timeWindow: Duration(hours: 24),
        );
        
        // Suggest weight adjustment
        final weightUpdate = _weightOptimizer.calculateAdjustment(
          currentWeights: config.retrievalWeights,
          performanceData: methodPerformance,
        );
        
        if (weightUpdate.confidence > 0.8) {
          configUpdates.add(ConfigUpdate(
            path: '.ai_os/auto_config/retrieval_weights.json',
            changes: {'hybrid_weights': weightUpdate.newWeights},
            reason: 'auto_optimization:precision_decline',
            requiresApproval: true, // Sensitive change
          ));
        }
      }
    }
    
    // Example: Auto-update chunking rules when new content type detected
    if (event is IngestionCompleteEvent) {
      final contentType = event.result.contentType;
      if (contentType.isNewType && contentType.chunkingStrategy == null) {
        // Suggest chunking strategy based on content analysis
        final suggestedStrategy = await _chunkingOptimizer.recommendStrategy(
          contentType: contentType,
          sampleChunks: event.generatedChunks.take(5).toList(),
        );
        
        configUpdates.add(ConfigUpdate(
          path: '.ai_os/auto_config/chunking_rules.json',
          changes: {
            'content_types': {
              contentType.mime: {
                'strategy': suggestedStrategy.name,
                'params': suggestedStrategy.params,
                'auto_detected': true,
              }
            }
          },
          reason: 'auto_detection:new_content_type',
          requiresApproval: false, // Safe to auto-apply
        ));
      }
    }
    
    if (configUpdates.isEmpty) return SyncResult.noOp();
    
    // Apply updates with rollback capability
    final appliedUpdates = <ConfigUpdate>[];
    for (final update in configUpdates) {
      if (update.requiresApproval) {
        // Queue for user review
        context.enqueueUserNotification(ConfigChangeSuggestion(update));
      } else {
        // Auto-apply with backup
        await _configService.applyUpdateWithBackup(update);
        appliedUpdates.add(update);
      }
    }
    
    // Emit config change event for downstream sync
    if (appliedUpdates.isNotEmpty) {
      context.enqueueSyncEvent(ConfigAutoUpdateEvent(
        configPath: appliedUpdates.first.path,
        previousValues: {}, // Would be populated from backup
        newValues: {}, // Would be populated from applied changes
        optimizationReason: appliedUpdates.map((u) => u.reason).join(', '),
        requiresUserApproval: appliedUpdates.any((u) => u.requiresApproval),
      ));
    }
    
    return SyncResult.success(
      affectedComponents: configUpdates.map((u) => 'config:${u.path}').toList(),
      downstreamTriggers: appliedUpdates.isNotEmpty 
        ? ['rag_engine_reinit', 'skill_context_refresh'] 
        : [],
    );
  }
}
```

### 5. UI State Sync Handler (Real-Time User Interface Updates)
```dart
class UISyncHandler implements SyncHandler {
  @override
  List<Type> get subscribedEvents => [
    GraphMutatedEvent,
    ChatMessageEvent,
    SkillExecutedEvent,
    ConfigAutoUpdateEvent,
    SyncProgressEvent,
  ];
  
  @override
  Future<SyncResult> execute(SyncEvent event, SyncContext context) async {
    // Debounce rapid UI updates to avoid jank
    await _debouncer.waitIfRecent(event.source, Duration(milliseconds: 100));
    
    final uiUpdates = <UIUpdate>[];
    
    if (event is GraphMutatedEvent) {
      // Update graph view: add/remove nodes, animate edge changes
      uiUpdates.add(UIUpdate.graphMutation(
        addedNodes: event.addedNodes,
        updatedNodes: event.updatedNodes,
        addedEdges: event.addedEdges,
        animation: _chooseAnimation(event.reason),
      ));
      
      // If centrality changed, update node sizes/colors
      if (event.updatedNodes.isNotEmpty) {
        uiUpdates.add(UIUpdate.nodeStyleRefresh(
          nodeIds: event.updatedNodes,
          styleProperties: ['size', 'color', 'border'],
        ));
      }
    }
    
    if (event is ChatMessageEvent) {
      // Append message to chat UI; highlight cited chunks
      uiUpdates.add(UIUpdate.chatAppend(
        sessionId: event.sessionId,
        turn: event.turn,
        citedChunkIds: event.retrievedChunkIds,
        scrollToBottom: true,
      ));
      
      // If entities extracted, show entity chips in context panel
      if (event.extractedEntities.isNotEmpty) {
        uiUpdates.add(UIUpdate.contextPanelUpdate(
          newEntities: event.extractedEntities,
          animation: AnimationType.fadeIn,
        ));
      }
    }
    
    if (event is SkillExecutedEvent) {
      // Show execution result in dashboard; update skill history
      uiUpdates.add(UIUpdate.skillExecutionResult(
        skillId: event.result.skillId,
        status: event.result.success ? ExecutionStatus.SUCCESS : ExecutionStatus.FAILED,
        outputPreview: event.result.outputPreview,
        duration: event.result.duration,
      ));
      
      // If output file created, show in file explorer
      if (event.result.outputFilePath != null) {
        uiUpdates.add(UIUpdate.fileExplorerRefresh(
          folderPath: p.dirname(event.result.outputFilePath!),
          highlightFile: event.result.outputFilePath,
        ));
      }
    }
    
    if (event is ConfigAutoUpdateEvent) {
      // Show non-intrusive notification for auto-applied config changes
      if (!event.requiresUserApproval) {
        uiUpdates.add(UIUpdate.toastNotification(
          message: 'System optimized: ${event.optimizationReason}',
          duration: Duration(seconds: 3),
          action: 'View Details',
          onTap: () => _openObservabilityDashboard(),
        ));
      }
    }
    
    if (uiUpdates.isEmpty) return SyncResult.noOp();
    
    // Batch UI updates for efficient rendering
    await _uiService.applyBatchUpdates(uiUpdates);
    
    return SyncResult.success(
      affectedComponents: ['ui_layer'],
      metrics: {'updates_applied': uiUpdates.length},
    );
  }
}
```

---

## 🔁 Conflict Resolution & Provenance System

### Conflict Detection Strategies
```dart
class ConflictResolver {
  // Detect conflicts before applying sync
  Future<ConflictCheckResult> checkForConflicts({
    required SyncEvent event,
    required List<SyncComponent> affectedComponents,
  }) async {
    final conflicts = <Conflict>[];
    
    for (final component in affectedComponents) {
      // Check if component was modified since event was generated
      final currentState = await _stateService.getCurrentState(component.nodeId);
      final eventState = event.payload['expected_state'];
      
      if (currentState.hash != eventState?.hash) {
        conflicts.add(Conflict(
          component: component,
          type: ConflictType.STATE_MISMATCH,
          currentState: currentState,
          expectedState: eventState,
          resolutionStrategy: _chooseResolutionStrategy(component, event),
        ));
      }
      
      // Check for concurrent modifications from other events
      final concurrentEvents = await _eventBus.getConcurrentEvents(
        component: component.nodeId,
        since: event.timestamp,
      );
      
      if (concurrentEvents.isNotEmpty) {
        conflicts.add(Conflict(
          component: component,
          type: ConflictType.CONCURRENT_MODIFICATION,
          concurrentEvents: concurrentEvents,
          resolutionStrategy: ConflictResolutionStrategy.LAST_WRITE_WINS,
        ));
      }
    }
    
    return ConflictCheckResult(
      hasConflicts: conflicts.isNotEmpty,
      conflicts: conflicts,
      canProceedAutomatically: conflicts.every((c) => c.isAutoResolvable),
    );
  }
  
  // Choose resolution strategy based on component type and event
  ConflictResolutionStrategy _chooseResolutionStrategy(
    SyncComponent component,
    SyncEvent event,
  ) {
    // User-edited files: prefer user changes
    if (component.isUserEditable && event.source != 'user') {
      return ConflictResolutionStrategy.PREFER_USER;
    }
    
    // System-generated configs: prefer latest optimization
    if (component.isSystemGenerated) {
      return ConflictResolutionStrategy.LAST_WRITE_WINS;
    }
    
    // Graph structure: merge if possible, else flag for review
    if (component.type == ComponentType.KNOWLEDGE_GRAPH) {
      return ConflictResolutionStrategy.MERGE_OR_FLAG;
    }
    
    // Default: last write wins with audit log
    return ConflictResolutionStrategy.LAST_WRITE_WINS_WITH_AUDIT;
  }
  
  // Execute resolution
  Future<ResolutionResult> resolveConflict(Conflict conflict) async {
    switch (conflict.resolutionStrategy) {
      case ConflictResolutionStrategy.PREFER_USER:
        return await _resolvePreferUser(conflict);
      case ConflictResolutionStrategy.LAST_WRITE_WINS:
        return await _resolveLastWriteWins(conflict);
      case ConflictResolutionStrategy.MERGE_OR_FLAG:
        return await _resolveMergeOrFlag(conflict);
      case ConflictResolutionStrategy.LAST_WRITE_WINS_WITH_AUDIT:
        return await _resolveWithAudit(conflict);
      default:
        return ResolutionResult.flagForManualReview(conflict);
    }
  }
}
```

### Provenance Tracking: Full Audit Trail
```dart
class ProvenanceLogger {
  // Log every sync operation with full context
  Future<void> logSyncOperation({
    required SyncEvent triggerEvent,
    required List<SyncComponent> affectedComponents,
    required SyncResult result,
    required Duration executionTime,
    ConflictCheckResult? conflictCheck,
  }) async {
    final logEntry = SyncAuditLogEntry(
      timestamp: DateTime.now(),
      triggerEvent: _serializeEvent(triggerEvent),
      affectedComponents: affectedComponents.map((c) => c.nodeId).toList(),
      actions: result.actions,
      executionTimeMs: executionTime.inMilliseconds,
      success: result.success,
      conflictResolved: conflictCheck?.hasConflicts == true,
      resolutionStrategy: conflictCheck?.conflicts.first.resolutionStrategy,
      systemState: await _captureSystemSnapshot(),
    );
    
    // Append to immutable audit log
    await _auditLog.append(logEntry);
    
    // Update per-component provenance
    for (final component in affectedComponents) {
      await _updateComponentProvenance(
        nodeId: component.nodeId,
        event: triggerEvent,
        result: result,
      );
    }
    
    // If sync failed, trigger alert
    if (!result.success) {
      await _alertService.logSyncFailure(logEntry);
    }
  }
  
  // Query provenance for debugging or user review
  Future<ProvenanceQueryResult> queryProvenance({
    required String nodeId,
    DateTime? startTime,
    DateTime? endTime,
    EventType? eventType,
  }) async {
    final entries = await _auditLog.query(
      nodeId: nodeId,
      startTime: startTime,
      endTime: endTime,
      eventType: eventType,
      limit: 100,
    );
    
    return ProvenanceQueryResult(
      nodeId: nodeId,
      entries: entries,
      summary: _generateProvenanceSummary(entries),
      rollbackOptions: _identifyRollbackPoints(entries),
    );
  }
}
```

---

## 📊 Sync Observability Dashboard: Real-Time System Health

### Dashboard UI Components
```
┌─────────────────────────────────────────┐
│ 🔄 Real-Time Sync Observatory           │
├─────────────────────────────────────────┤
│ 📡 Event Stream (Live)                  │
│ [●] FileChanged: ACE/Atlas/Concepts/ML.md│
│ [●] ChatMessage: session_abc123         │
│ [●] GraphMutated: +3 nodes, +5 edges    │
│ [●] ConfigAutoUpdate: retrieval_weights │
│                                         │
│ 📈 Sync Performance (Last Hour)         │
│ • Events Processed: ████████░░ 1,247   │
│ • Avg Latency: ██████░░░░░ 342ms       │
│ • Success Rate: █████████░ 98.2% ▲0.3% │
│ • Conflicts Resolved: 12 (auto: 11)    │
│                                         │
│ 🗂️ Cascade Depth Distribution          │
│ Depth 1: ████████████ 68%              │
│ Depth 2: ██████░░░░░░ 24%              │
│ Depth 3: ██░░░░░░░░░░ 8%               │
│                                         │
│ ⚠️ Active Alerts                        │
│ • High latency on vector index updates  │
│   [Investigate] [Snooze]                │
│ • 3 pending config changes need review  │
│   [Review Now]                          │
│                                         │
│ 🎛️ Sync Controls                       │
│ [Pause Auto-Sync] [Force Full Sync]    │
│ [Export Audit Log] [Reset Sync State]  │
└─────────────────────────────────────────┘
```

### Key Sync Metrics Tracked
| Metric | Description | Target |
|--------|-------------|--------|
| **Event Throughput** | Events processed per second | > 50/s sustained |
| **Sync Latency P95** | Time from event to all syncs complete | < 1.5s |
| **Cascade Efficiency** | % of affected components that actually needed updating | > 85% |
| **Conflict Rate** | % of syncs requiring conflict resolution | < 2% |
| **Auto-Resolution Rate** | % of conflicts resolved without user intervention | > 90% |
| **Rollback Success** | % of rollbacks that restore consistent state | 100% |
| **UI Jank Score** | Frame drops during sync-induced UI updates | < 1% of frames |

### Real-Time Debugging Tools
```dart
class SyncDebugger {
  // Replay events from a specific time window
  Future<ReplayResult> replayEvents({
    required DateTime startTime,
    required DateTime endTime,
    bool dryRun = true,
  }) async {
    final events = await _auditLog.queryEvents(
      startTime: startTime,
      endTime: endTime,
    );
    
    if (dryRun) {
      // Simulate sync without applying changes
      return await _simulateSyncCascade(events);
    } else {
      // Actually re-execute syncs (use with caution)
      return await _executeSyncCascade(events, force: true);
    }
  }
  
  // Visualize dependency cascade for a specific event
  Future<CascadeVisualization> visualizeCascade(SyncEvent event) async {
    final affected = await _dependencyGraph.resolveCascade(
      sourceEvent: event,
      maxDepth: 5,
    );
    
    return CascadeVisualization(
      sourceEvent: event,
      affectedComponents: affected,
      dependencyGraph: _dependencyGraph.subgraph(affected.map((c) => c.nodeId)),
      estimatedTotalTime: affected.fold(
        Duration.zero,
        (sum, c) => sum + c.metadata.estimatedSyncTime,
      ),
    );
  }
  
  // Force sync state reset for debugging
  Future<void> resetSyncState({
    String? nodeId, // Reset specific component or all
    bool preserveAuditLog = true,
  }) async {
    if (nodeId != null) {
      await _stateService.resetComponentState(nodeId);
    } else {
      await _stateService.resetAllSyncState();
    }
    
    if (!preserveAuditLog) {
      await _auditLog.clear();
    }
    
    // Trigger full re-sync from current file state
    await _orchestrator.triggerFullResync();
  }
}
```

---

## 🏗️ Technical Architecture: Sync-First Implementation

### Core Sync Services (Isolate-Based)
```
lib/core/sync/
├── event_bus/
│   ├── event_bus.dart           # Typed event pub/sub with persistence
│   ├── event_types.dart         # All SyncEvent subclasses
│   └── event_persister.dart     # Append-only JSONL log + replay checkpoint
│
├── orchestrator/
│   ├── sync_orchestrator.dart   # Central event router + priority queue
│   ├── dependency_graph.dart    # Component dependency tracking
│   ├── priority_queue.dart      # Concurrent sync execution with limits
│   └── sync_context.dart        # Context passed to handlers (progress, enqueue)
│
├── handlers/
│   ├── sync_handler.dart        # Abstract handler interface
│   ├── graph_sync_handler.dart  # Live graph updates
│   ├── vector_index_handler.dart# Incremental embedding updates
│   ├── skill_context_handler.dart# Auto-update skill configs
│   ├── config_auto_handler.dart # Self-optimizing system configs
│   ├── ui_sync_handler.dart     # Real-time UI updates
│   └── provenance_handler.dart  # Audit logging + rollback management
│
├── conflict/
│   ├── conflict_resolver.dart   # Detection + resolution strategies
│   ├── resolution_strategies.dart# PREFER_USER, MERGE, LAST_WRITE_WINS, etc.
│   └── rollback_manager.dart    # Backup creation + state restoration
│
├── observability/
│   ├── sync_metrics.dart        # Real-time metric collection
│   ├── dashboard_service.dart   # Dashboard data provider
│   ├── alert_system.dart        # Anomaly detection + notifications
│   └── debugger.dart            # Replay, visualize, reset tools
│
└── utilities/
    ├── sha256_diff.dart         # Efficient content diffing
    ├── debounce.dart            # UI update debouncing
    ├── platform_sync.dart       # Android/Windows concurrency tuning
    └── sync_testing.dart        # Mock events for integration tests
```

### Platform-Specific Sync Optimizations
| Platform | Concurrency Model | Storage Strategy | Memory Management |
|----------|------------------|-----------------|------------------|
| **Android** | Max 2 concurrent sync handlers; background isolation via WorkManager | SQLite WAL mode for concurrent reads; vector index memory-mapped | Aggressive LRU for embedding cache; pause non-critical syncs on low memory |
| **Windows** | Max 4 concurrent sync handlers; use thread pool for I/O-bound tasks | Direct file I/O with file locks; vector index can use larger RAM cache | Preload frequently-synced components; background syncs yield to foreground |
| **Cross-Platform** | Abstract concurrency via `PlatformSyncConfig`; user-adjustable limits | Unified `SyncStorageAdapter` interface; platform-specific implementations | User-controlled cache sizes; auto-throttle when battery/storage low |

---

## 🚀 MVP Scope vs. Phased Sync Rollout

### MVP (v4.0) - "Real-Time Sync Foundation"
- ✅ Event bus with typed events + append-only persistence
- ✅ Dependency graph with cascade resolution (max depth 3)
- ✅ Core sync handlers: Graph, Vector Index, UI (basic)
- ✅ SHA256 diffing + incremental updates (no full rebuilds)
- ✅ Conflict resolution: LAST_WRITE_WINS_WITH_AUDIT + PREFER_USER
- ✅ Provenance logging: sync audit trail + per-component `.sync.json`
- ✅ Observability dashboard: event stream, latency metrics, conflict counter
- ✅ Android + Windows builds with platform-tuned concurrency

### v4.1 - "Advanced Sync Intelligence"
- 🔄 Merge-based conflict resolution for graph structure
- 🔄 Learned cascade prediction: anticipate which components will need updating
- 🔄 User preference learning: adapt sync priorities based on usage patterns
- 🔄 Background sync optimization: battery/storage-aware throttling
- 🔄 Sync testing framework: mock events for deterministic integration tests

### v4.2 - "Collaborative Sync + Team Features"
- 🔄 Multi-vault sync: propagate changes across user-controlled vaults (encrypted)
- 🔄 Sync conflict resolution UI: side-by-side diff + merge tool for manual review
- 🔄 Sync policy export/import: share sync rules across team members
- 🔄 Audit log export: compliance-ready sync history with cryptographic signatures

---

## ⚠️ Risks & Mitigations (Sync-Specific)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Sync cascade infinite loops** | High | Max cascade depth (configurable); cycle detection in dependency graph; event deduplication by ID |
| **Conflict resolution data loss** | High | Always create backup before auto-applying; user-review mode for sensitive changes; full audit trail for rollback |
| **UI jank from rapid sync updates** | Medium | Debounce UI updates; batch DOM mutations; prioritize user-facing syncs; use Flutter's `SchedulerBinding` for frame timing |
| **Storage bloat from audit logs** | Medium | Configurable log retention; auto-archive old logs; compress JSONL entries; user-controlled log levels |
| **Platform-specific sync failures** | Medium | Isolate platform code behind `PlatformSyncAdapter`; comprehensive integration tests on both Android emulator and Windows CI |
| **User confusion: auto-updating configs** | Low | Clear notifications for auto-changes; "Undo Last Auto-Update" button; toggle per-feature auto-sync; detailed provenance view |

---

## ✅ Acceptance Criteria (Sync-Focused)

1. **Event-Driven Sync**
   - [ ] File change triggers graph update + vector index refresh within 2s
   - [ ] Chat message extracts entities → creates graph nodes → updates UI in real-time
   - [ ] Skill execution auto-updates its own retrieval config based on performance metrics

2. **Conflict Resolution**
   - [ ] Concurrent edits to same file: user's edit takes precedence, system changes logged
   - [ ] Graph structure conflicts: merge if possible, else flag for manual review with diff view
   - [ ] All conflicts logged to audit trail with resolution strategy and outcome

3. **Provenance & Rollback**
   - [ ] Every `.md` file has companion `.sync.json` with full change history
   - [ ] User can view provenance: "This chunk was updated by chat session XYZ at 14:32"
   - [ ] One-click rollback to any previous sync version with consistency verification

4. **Observability & Debugging**
   - [ ] Dashboard shows live event stream with filter by type/source
   - [ ] Sync latency P95 < 1.5s on mid-tier Android device with 10K files
   - [ ] Debugger can replay last hour of events in dry-run mode for testing

5. **Performance & Resource Usage**
   - [ ] Sync operations run in background isolates; UI remains responsive at 60 FPS
   - [ ] Memory usage stable during sustained sync activity (no leaks)
   - [ ] Battery impact < 5% per hour of typical usage on Android

6. **User Control & Transparency**
   - [ ] Toggle per-feature auto-sync: "Auto-update graph", "Auto-optimize skills", etc.
   - [ ] Non-intrusive notifications for auto-applied changes with "Undo" option
   - [ ] Export full audit log as JSONL for external analysis or backup

---

## 📦 Deliverables for Claude Project Generation

1. **Complete Flutter project scaffold** with sync-optimized folder structure + `.sync.json` sidecar pattern
2. **Riverpod providers** for: SyncState, EventBusState, DependencyGraphState, ObservabilityState
3. **Isolate implementations** for: EventProcessing, SyncOrchestration, ConflictResolution, ProvenanceLogging
4. **Service interfaces with mocks**: `EventBus`, `SyncOrchestrator`, `ConflictResolver`, `ProvenanceLogger`
5. **UI components**: LiveEventStreamWidget, SyncDashboard, ProvenanceViewer, ConflictResolutionDialog
6. **Event taxonomy** with all SyncEvent subclasses + serialization/deserialization
7. **Dependency graph implementation** with cascade resolution + cycle detection
8. **Sample sync handlers** for Graph, Vector Index, and UI with full provenance tracking
9. **Platform adapters** for Android/Windows concurrency + storage optimization
10. **Documentation**: `SYNC_ARCHITECTURE.md`, `CONFLICT_RESOLUTION_GUIDE.md`, `DEBUGGING_SYNC.md`, `PRIVACY_SYNC_MODEL.md`
11. **Test suite**: Unit tests for event routing; integration tests for cascade sync; performance benchmarks for latency

---

> **Final Note to Claude**: This PRD v4.0 establishes a **real-time, event-driven sync architecture** where every change—file edit, chat message, ingestion completion, skill execution—ripples intelligently through the system. The knowledge graph, vector index, skill configs, and UI all stay in sync automatically, with full provenance and user control. Prioritize: (1) keeping sync operations incremental and efficient (SHA256 diffing, dependency graphs), (2) making conflict resolution safe and transparent (backups, audit trails, user override), (3) ensuring UI remains responsive during sync cascades (debouncing, batching, isolate isolation), and (4) maintaining the "File Over AI" philosophy—every sync operation mutates plain `.md` files with human-readable `.sync.json` sidecars. Build incrementally: ship MVP with LAST_WRITE_WINS resolution and basic cascade depth, then enhance with merge strategies and learned optimization. The system should feel alive—self-organizing, self-optimizing, but always under the user's control.

*Generated for local execution on Android + Windows. Your files, your graph, your sync.* 🗝️🔄🧠