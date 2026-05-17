import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import 'package:go_router/go_router.dart';
import '../../vault/screens/vault_screen.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class KGNode {
  final String id, label, contentType;
  final String? source;
  final int community, degree;
  const KGNode(
      {required this.id,
      required this.label,
      required this.community,
      required this.degree,
      required this.contentType,
      this.source});
  factory KGNode.fromJson(Map j) => KGNode(
      id: j['id'] ?? '',
      label: j['label'] ?? '',
      community: j['community'] ?? 0,
      degree: j['degree'] ?? 1,
      contentType: j['content_type'] ?? j['type'] ?? 'text',
      source: j['source'] ?? j['path']);
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'community': community,
        'degree': degree,
        'content_type': contentType,
        'source': source
      };
}

class KGCommunity {
  final int id;
  final int nodeCount;
  final String name;
  final String summary;
  const KGCommunity(
      {required this.id,
      required this.nodeCount,
      required this.name,
      required this.summary});
  factory KGCommunity.fromJson(Map j) => KGCommunity(
      id: j['id'] ?? 0,
      nodeCount: j['nodeCount'] ?? 0,
      name: j['name'] ?? 'Cluster ${j['id']}',
      summary: j['summary'] ?? '');
  Map<String, dynamic> toJson() =>
      {'id': id, 'nodeCount': nodeCount, 'name': name, 'summary': summary};
}

class KGEdge {
  final String source, target, type;
  final double weight;
  const KGEdge(
      {required this.source,
      required this.target,
      required this.type,
      this.weight = 1});
  factory KGEdge.fromJson(Map j) => KGEdge(
      source: j['source'] ?? '',
      target: j['target'] ?? '',
      type: j['type'] ?? 'direct',
      weight: (j['weight'] ?? 1).toDouble());
  Map<String, dynamic> toJson() =>
      {'source': source, 'target': target, 'type': type, 'weight': weight};
}

// ── State ─────────────────────────────────────────────────────────────────────
class GraphState {
  final List<KGNode> nodes;
  final List<KGEdge> edges;
  final List<KGCommunity> communities;
  final bool loading;
  final String? selectedId;
  final int? selectedCommunity;
  final String search;
  final List<int> hiddenCommunities;
  final String activeSource;
  final String? error;
  final bool initialized;
  final bool showLabels;
  final double repelForce;
  final double centerForce;
  final double nodeSize;
  final double linkThickness;
  final bool showArrows;

  const GraphState({
    this.nodes = const [],
    this.edges = const [],
    this.communities = const [],
    this.loading = false,
    this.selectedId,
    this.selectedCommunity,
    this.search = '',
    this.hiddenCommunities = const [],
    this.activeSource = 'vault',
    this.error,
    this.initialized = false,
    this.showLabels = true,
    this.repelForce = -12000.0,
    this.centerForce = 0.05,
    this.nodeSize = 0.8,
    this.linkThickness = 0.6,
    this.showArrows = false,
  });

  GraphState copyWith({
    List<KGNode>? nodes,
    List<KGEdge>? edges,
    List<KGCommunity>? communities,
    bool? loading,
    String? selectedId,
    int? selectedCommunity,
    String? search,
    List<int>? hiddenCommunities,
    String? activeSource,
    String? error,
    bool? initialized,
    bool? showLabels,
    double? repelForce,
    double? centerForce,
    double? nodeSize,
    double? linkThickness,
    bool? showArrows,
    bool clearSelectedId = false,
    bool clearSelectedCommunity = false,
    bool clearError = false,
  }) =>
      GraphState(
        nodes: nodes ?? this.nodes,
        edges: edges ?? this.edges,
        communities: communities ?? this.communities,
        loading: loading ?? this.loading,
        selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
        selectedCommunity: clearSelectedCommunity ? null : (selectedCommunity ?? this.selectedCommunity),
        search: search ?? this.search,
        hiddenCommunities: hiddenCommunities ?? this.hiddenCommunities,
        activeSource: activeSource ?? this.activeSource,
        error: clearError ? null : (error ?? this.error),
        initialized: initialized ?? this.initialized,
        showLabels: showLabels ?? this.showLabels,
        repelForce: repelForce ?? this.repelForce,
        centerForce: centerForce ?? this.centerForce,
        nodeSize: nodeSize ?? this.nodeSize,
        linkThickness: linkThickness ?? this.linkThickness,
        showArrows: showArrows ?? this.showArrows,
      );
}

class GraphNotifier extends StateNotifier<GraphState> {
  GraphNotifier() : super(const GraphState());
  final _dio = apiDio;

  /// Called once when the screen first mounts via [ensureLoaded].
  bool _loadStarted = false;
  void ensureLoaded() {
    if (!_loadStarted) {
      _loadStarted = true;
      load();
    }
  }

  Future<void> load({String source = 'vault'}) async {
    state = state.copyWith(
        loading: true, 
        activeSource: 'vault', 
        clearError: true, 
        clearSelectedId: true,
        clearSelectedCommunity: true);
    try {
      List<KGNode> nodes = [];
      List<KGEdge> edges = [];
      List<KGCommunity> communities = [];

      final r = await _dio.get(ApiConstants.vaultGraph);
      nodes = (r.data['nodes'] as List)
          .map((n) => KGNode(
              id: n['id'] ?? '',
              label: n['title'] ?? n['label'] ?? '',
              community: n['community'] ?? 0,
              degree: n['degree'] ?? 0,
              contentType: 'note',
              source: n['path']))
          .toList();
      edges = (r.data['edges'] as List)
          .map((e) => KGEdge.fromJson(e as Map))
          .toList();
      if (r.data['communities'] != null) {
        communities = (r.data['communities'] as List)
            .map((c) => KGCommunity.fromJson(c as Map))
            .toList();
      }

      final box = Hive.box('cyborg_cache');
      box.put('graph_nodes', nodes.map((n) => n.toJson()).toList());
      box.put('graph_edges', edges.map((e) => e.toJson()).toList());
      box.put('graph_communities', communities.map((c) => c.toJson()).toList());

      state = state.copyWith(
          nodes: nodes,
          edges: edges,
          communities: communities,
          loading: false,
          initialized: true);
    } catch (e) {
      final box = Hive.box('cyborg_cache');
      final cachedNodes = box.get('graph_nodes');
      final cachedEdges = box.get('graph_edges');
      final cachedComms = box.get('graph_communities');
      if (cachedNodes != null && cachedEdges != null) {
        final nodes = (cachedNodes as List)
            .map((n) => KGNode.fromJson(n as Map))
            .toList();
        final edges = (cachedEdges as List)
            .map((e) => KGEdge.fromJson(e as Map))
            .toList();
        final comms = cachedComms != null
            ? (cachedComms as List)
                .map((c) => KGCommunity.fromJson(c as Map))
                .toList()
            : <KGCommunity>[];
        state = state.copyWith(
            nodes: nodes,
            edges: edges,
            communities: comms,
            loading: false,
            initialized: true,
            error: 'Offline mode: Showing cached local graph.');
      } else {
        state = state.copyWith(
            loading: false,
            initialized: true,
            error:
                'Backend offline and no local cache — start the Cyborg backend to load the graph.');
      }
    }
  }

  Future<void> ingest(String path) async {
    try {
      await _dio.post(ApiConstants.graphIngest, data: {'path': path});
      await load(source: state.activeSource);
    } catch (_) {}
  }

  void select(String? id) =>
      state = state.copyWith(
        selectedId: id, 
        clearSelectedId: id == null,
        clearSelectedCommunity: true);

  void selectCommunity(int? id) =>
      state = state.copyWith(
        selectedCommunity: id, 
        clearSelectedCommunity: id == null,
        clearSelectedId: true);
  void setSearch(String q) => state = state.copyWith(search: q);
  void toggleCommunity(int id) {
    final h = List<int>.from(state.hiddenCommunities);
    h.contains(id) ? h.remove(id) : h.add(id);
    state = state.copyWith(hiddenCommunities: h);
  }

  Future<void> clearGraph({bool keepInitial = false}) async {
    try {
      await _dio.delete('graph/clear', queryParameters: {'keep_initial': keepInitial.toString()});
      await load(source: state.activeSource);
    } catch (_) {}
  }

  void toggleLabels() => state = state.copyWith(showLabels: !state.showLabels);

  void setRepelForce(double v) => state = state.copyWith(repelForce: v);
  void setCenterForce(double v) => state = state.copyWith(centerForce: v);
  void setNodeSize(double v) => state = state.copyWith(nodeSize: v);
  void setLinkThickness(double v) => state = state.copyWith(linkThickness: v);
  void toggleArrows() => state = state.copyWith(showArrows: !state.showArrows);
}

final graphProvider = StateNotifierProvider<GraphNotifier, GraphState>(
  (_) => GraphNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────
class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});
  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends ConsumerState<KnowledgeGraphScreen> {
  final _searchCtrl = TextEditingController();
  final _ingestCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(graphProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ingestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(graphProvider);
    final n = ref.read(graphProvider.notifier);
    final selected = s.selectedId != null
        ? s.nodes.where((node) => node.id == s.selectedId).firstOrNull
        : null;

    return Column(children: [
      LayoutBuilder(builder: (ctx, constraints) {
        final narrow = constraints.maxWidth < 520;
        return Container(
          height: narrow ? 96 : 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: AppColors.surface,
          child: narrow
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(children: [
                    const Icon(Icons.hub_outlined,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text('Knowledge Graph',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600))),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('${s.nodes.length}n · ${s.edges.length}e',
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 10))),
                    const SizedBox(width: 6),
                    IconButton(
                        icon: const Icon(Icons.tune, size: 18),
                        padding: EdgeInsets.zero,
                        tooltip: 'Graph Settings',
                        onPressed: () => _showMobileSettings(context, s, n)),
                    IconButton(
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        padding: EdgeInsets.zero,
                        tooltip: 'Ingest files',
                        onPressed: () => _showIngest(context, n)),
                    IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        padding: EdgeInsets.zero,
                        onPressed: () => n.load(source: s.activeSource)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const SizedBox(width: 8),
                    Expanded(
                        child: SizedBox(
                            height: 30,
                            child: TextField(
                                controller: _searchCtrl,
                                onChanged: n.setSearch,
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 12),
                                decoration: const InputDecoration(
                                    hintText: 'Search…',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.search, size: 14),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4))))),
                  ]),
                ])
              : Row(children: [
                  const Icon(Icons.hub_outlined,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Knowledge Graph',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          '${s.nodes.length} nodes · ${s.edges.length} edges',
                          style: const TextStyle(
                              color: AppColors.accent, fontSize: 11))),
                  const Spacer(),
                  SizedBox(
                      width: 200,
                      child: TextField(
                          controller: _searchCtrl,
                          onChanged: n.setSearch,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 12),
                          decoration: const InputDecoration(
                              hintText: 'Search nodes...',
                              isDense: true,
                              prefixIcon: Icon(Icons.search, size: 14),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6)))),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      tooltip: 'Ingest files',
                      onPressed: () => _showIngest(context, n)),
                  IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined,
                          size: 18, color: AppColors.accentRed),
                      tooltip: 'Clear Graph',
                      onPressed: () => _showClearConfirm(context, n)),
                  IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () => n.load(source: s.activeSource)),
                  const SizedBox(width: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.label_outline, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: s.showLabels,
                        onChanged: (_) => n.toggleLabels(),
                        activeColor: AppColors.accent,
                      ),
                    ),
                  ]),
                ]),
        );
      }),
      const Divider(height: 1),
      Expanded(
        child: Stack(
          children: [
            Row(children: [
              Expanded(
                  child: !s.initialized
                      ? const Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Connecting to knowledge graph…',
                                  style: TextStyle(color: AppColors.textSecondary))
                            ]))
                      : s.loading
                          ? const Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading graph…',
                                      style:
                                          TextStyle(color: AppColors.textSecondary))
                                ]))
                          : Container(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.backgroundMain
                                  : const Color(0xFFF9FAFB),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _GraphCanvas(
                                    nodes: s.nodes,
                                    edges: s.edges,
                                    search: s.search,
                                    hiddenCommunities: s.hiddenCommunities,
                                    onNodeTap: n.select,
                                    selectedId: s.selectedId,
                                    showLabels: s.showLabels,
                                    repelForce: s.repelForce,
                                    centerForce: s.centerForce,
                                    nodeSize: s.nodeSize,
                                    linkThickness: s.linkThickness,
                                    showArrows: s.showArrows,
                                  ),
                                ]),
                            )),
              if (!Responsive.isMobile(context))
                Container(
                  width: 250,
                  decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(left: BorderSide(color: AppColors.border))),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExpansionTile(
                          initiallyExpanded: true,
                          title: const Text('COMMUNITIES',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1)),
                          children: [
                            SizedBox(
                              height: 250,
                              child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: _communityItems(s, n)),
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        ExpansionTile(
                          title: const Text('GRAPH SETTINGS',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1)),
                          children: [
                            _GraphSidebarControls(state: s, notifier: n),
                          ],
                        ),
                        const Divider(height: 1),
                        if (selected != null)
                          _NodeInfo(node: selected)
                        else if (s.selectedCommunity != null)
                          _CommunityInfo(
                              community: s.communities.firstWhere(
                                  (c) => c.id == s.selectedCommunity,
                                  orElse: () => KGCommunity(
                                      id: s.selectedCommunity!,
                                      nodeCount: 0,
                                      name: 'Cluster ${s.selectedCommunity}',
                                      summary: 'Loading...')))
                        else
                          const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Click a node or cluster to inspect',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11))),
                      ],
                    ),
                  ),
                ),
            ]),
            if (selected != null)
              _FloatingNodeInfo(
                node: selected,
                onClose: () {
                  ref.read(graphProvider.notifier).select(null);
                },
              ),
          ],
        ),
      ),
    ]);
  }

  void _showMobileSettings(BuildContext context, GraphState s, GraphNotifier n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSidebar,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Text('Graph Settings & Clusters',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ExpansionTile(
                    title: const Text('COMMUNITIES'),
                    children: _communityItems(s, n),
                  ),
                  ExpansionTile(
                    title: const Text('SETTINGS'),
                    children: [
                      _GraphSidebarControls(state: s, notifier: n),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.accentRed),
                        title: const Text('Clear Graph', style: TextStyle(color: AppColors.accentRed)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showClearConfirm(context, n);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _communityItems(GraphState s, GraphNotifier n) {
    final List<KGCommunity> list =
        s.communities.isNotEmpty ? s.communities : _fallbackCommunities(s);
    return list.map((c) {
      final hidden = s.hiddenCommunities.contains(c.id);
      final color =
          AppColors.communityColors[c.id % AppColors.communityColors.length];
      final isSelected = s.selectedCommunity == c.id;

      return Material(
        color: isSelected
            ? AppColors.accent.withOpacity(0.08)
            : Colors.transparent,
        child: ListTile(
            dense: true,
            leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hidden ? color.withOpacity(0.2) : color)),
            title: Text(c.name,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: hidden
                        ? AppColors.textMuted
                        : AppColors.textSecondary)),
            trailing: Text('${c.nodeCount}',
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            onTap: () => n.selectCommunity(isSelected ? null : c.id),
            onLongPress: () => n.toggleCommunity(c.id)),
      );
    }).toList();
  }

  List<KGCommunity> _fallbackCommunities(GraphState s) {
    final ids = s.nodes.map((node) => node.community).toSet().toList()..sort();
    return ids
        .map((id) => KGCommunity(
            id: id,
            nodeCount: s.nodes.where((n) => n.community == id).length,
            name: 'Cluster $id',
            summary: ''))
        .toList();
  }

  void _showClearConfirm(BuildContext ctx, GraphNotifier n) {
    showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Clear Knowledge Graph?',
                  style: TextStyle(color: AppColors.textPrimary)),
              content: const Text(
                  'This will delete all nodes and edges permanently.',
                  style: TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      n.clearGraph(keepInitial: true);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text('Keep Initial')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRed),
                    onPressed: () {
                      n.clearGraph(keepInitial: false);
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text('Clear All')),
              ],
            ));
  }

  void _showIngest(BuildContext ctx, GraphNotifier n) {
    // Use dialog's own BuildContext for pop — not the shell ctx,
    // which would pop the go_router page route instead of the dialog.
    showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Ingest into Knowledge Graph',
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 360,
                        child: TextField(
                            controller: _ingestCtrl,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                                hintText: '/path/to/folder or Device IP/ID',
                                prefixIcon:
                                    Icon(Icons.folder_outlined, size: 16)))),
                    const SizedBox(height: 12),
                    const Text(
                        'Supports local folders, files, or connected devices via ADB/mDNS.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        n.ingest(_ingestCtrl.text);
                        Navigator.of(dialogCtx).pop();
                      },
                      child: const Text('Ingest')),
                ]));
  }
}

// ── Source Toggle ─────────────────────────────────────────────────────────────
class _SourceToggle extends StatelessWidget {
  final String active;
  final void Function(String) onSwitch;
  const _SourceToggle({required this.active, required this.onSwitch});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Tab('Documents', 'graph', active, onSwitch),
        _Tab('Vault', 'vault', active, onSwitch),
      ]));
}

class _Tab extends StatelessWidget {
  final String label, src, active;
  final void Function(String) fn;
  const _Tab(this.label, this.src, this.active, this.fn);
  @override
  Widget build(BuildContext context) {
    final sel = active == src;
    return GestureDetector(
        onTap: () => fn(src),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: sel
                    ? AppColors.accent.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: sel ? AppColors.accent : AppColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400))));
  }
}

// ── Obsidian-style Graph (Flutter CustomPainter force-directed) ───────────────
class _NodeLayout {
  final KGNode node;
  double x, y, vx, vy;
  _NodeLayout(this.node, this.x, this.y)
      : vx = 0,
        vy = 0;
}

class _GraphCanvas extends StatefulWidget {
  final List<KGNode> nodes;
  final List<KGEdge> edges;
  final String search;
  final List<int> hiddenCommunities;
  final void Function(String?) onNodeTap;
  final String? selectedId;
  final bool showLabels;
  final double repelForce;
  final double centerForce;
  final double nodeSize;
  final double linkThickness;
  final bool showArrows;

  const _GraphCanvas({
    required this.nodes,
    required this.edges,
    required this.search,
    required this.hiddenCommunities,
    required this.onNodeTap,
    this.selectedId,
    this.showLabels = true,
    required this.repelForce,
    required this.centerForce,
    required this.nodeSize,
    required this.linkThickness,
    required this.showArrows,
  });

  @override
  State<_GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<_GraphCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  final List<_NodeLayout> _layouts = [];
  double _scale = 1.0;
  Offset _pan = Offset.zero;
  Offset? _panStart;
  Offset? _panStartPan;
  bool _settled = false;
  String? _hoveredId;
  Offset? _mousePos; 
  int _ticks = 0;
  double _startScale = 1.0;

  @override
  void initState() {
    super.initState();
    _buildLayouts();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 600))
          ..addListener(_tick)
          ..repeat();
  }

  void _buildLayouts() {
    _layouts.clear();
    const cx = 400.0, cy = 300.0;
    _pan = Offset.zero;
    _scale = 1.0;
    
    final rng = math.Random();
    const goldenAngle = 2.399963229728653;
    
    for (var i = 0; i < widget.nodes.length; i++) {
      final r = 60.0 + 45.0 * math.sqrt(i.toDouble());
      final angle = i * goldenAngle;
      final jx = (rng.nextDouble() - 0.5) * 40;
      final jy = (rng.nextDouble() - 0.5) * 40;
      
      _layouts.add(_NodeLayout(
        widget.nodes[i],
        cx + r * math.cos(angle) + jx,
        cy + r * math.sin(angle) + jy,
      ));
    }
    _settled = false;
    _ticks = 0;
  }

  @override
  void didUpdateWidget(_GraphCanvas old) {
    super.didUpdateWidget(old);
    if (old.nodes.length != widget.nodes.length) {
      _buildLayouts();
      _settled = false;
      if (!_ticker.isAnimating) _ticker.repeat();
    }
    if (old.selectedId != widget.selectedId && widget.selectedId != null) {
      _centerOnNode(widget.selectedId!);
    }
    if (old.repelForce != widget.repelForce || old.centerForce != widget.centerForce) {
      _settled = false;
      _ticks = math.max(0, _ticks - 300); // More heat for setting changes
      if (!_ticker.isAnimating) _ticker.repeat();
    }
  }

  void _centerOnNode(String id) {
    final l = _layouts.where((x) => x.node.id == id).firstOrNull;
    if (l != null) {
      setState(() {
        _pan = Offset(400 - l.x * _scale, 300 - l.y * _scale);
      });
    }
  }

  void _tick() {
    if (_settled && _draggedNode == null) return;
    // Slower decay for large graphs to allow spreading
    final alpha = math.max(0.001, 1.0 * math.exp(-_ticks * 0.002)); 
    _ticks++;
    if (alpha < 0.01 && _draggedNode == null) {
      _settled = true;
      _ticker.stop();
      return;
    }

    final Map<String, _NodeLayout> byId = {
      for (var l in _layouts) l.node.id: l
    };

    // OBSIDIAN-FIDELITY PHYSICS: Smooth gliding, strong cluster separation, compact links
    final repelStrength = widget.repelForce.abs() * 150.0; // Moderate base repulsion
    final linkStrength = 0.08; // Stronger links to keep connected nodes closer
    final idealLinkDist = 50.0; // Much shorter links for tight clustering
    final centerStrength = widget.centerForce * 0.01; // Gentle pull to center

    for (var i = 0; i < _layouts.length; i++) {
      final a = _layouts[i];
      if (a == _draggedNode) continue;

      for (var j = i + 1; j < _layouts.length; j++) {
        final b = _layouts[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final distSq = dx * dx + dy * dy;
        
        if (distSq > 1500 * 1500) continue; // Further range for global spread

        final dist = math.sqrt(math.max(1.0, distSq));
        
        // Inverse Square Repulsion (Corrected Direction: Positive pushes away)
        double force = (repelStrength / distSq) * alpha;
        
        // --- Cluster Separation Logic ---
        if (a.node.community != b.node.community) {
          force *= 2.0; // Moderate push to differentiate clusters without exploding
        }
        
        // Smooth Anti-Collision
        final ra = (math.sqrt(a.node.degree.toDouble()) * 1.8 + 3.5).clamp(3.5, 18);
        final rb = (math.sqrt(b.node.degree.toDouble()) * 1.8 + 3.5).clamp(3.5, 18);
        final minSeparation = (ra + rb) * widget.nodeSize + 15.0;
        
        if (dist < minSeparation) {
          final overlap = minSeparation - dist;
          force += (overlap * 2.0) * alpha; // Smooth anti-collision spring
        }

        final fx = (dx / dist) * force;
        final fy = (dy / dist) * force;
        
        a.vx -= fx;
        a.vy -= fy;
        b.vx += fx;
        b.vy += fy;
      }
    }

    for (final edge in widget.edges) {
      final a = byId[edge.source], b = byId[edge.target];
      if (a == null || b == null) continue;
      final dx = b.x - a.x, dy = b.y - a.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 1) continue;

      final force = (dist - idealLinkDist) * linkStrength * alpha;
      final fx = (dx / dist) * force;
      final fy = (dy / dist) * force;

      if (a != _draggedNode) {
        a.vx += fx;
        a.vy += fy;
      }
      if (b != _draggedNode) {
        b.vx -= fx;
        b.vy -= fy;
      }
    }

    for (final l in _layouts) {
      if (l == _draggedNode) continue;
      
      // Global gravity pull towards center (400, 300)
      l.vx += (400 - l.x) * centerStrength * alpha;
      l.vy += (300 - l.y) * centerStrength * alpha;

      // Prevent explosion/NaNs with a high speed limit
      final speedSq = l.vx * l.vx + l.vy * l.vy;
      if (speedSq > 200 * 200) {
        final speed = math.sqrt(speedSq);
        l.vx = (l.vx / speed) * 200;
        l.vy = (l.vy / speed) * 200;
      }

      l.x += l.vx * 0.6;
      l.y += l.vy * 0.6;
      
      // Smooth Obsidian-style damping (gliding momentum instead of rigid stop)
      l.vx *= 0.88; 
      l.vy *= 0.88;
    }
    if (mounted) setState(() {});
  }

  _NodeLayout? _draggedNode;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchLower = widget.search.toLowerCase();
    return GestureDetector(
      onScaleStart: (d) {
        final hitId = _hitTest(d.localFocalPoint);
        if (hitId != null) {
          _draggedNode = _layouts.firstWhere((l) => l.node.id == hitId);
          _settled = false;
          if (!_ticker.isAnimating) _ticker.repeat();
          widget.onNodeTap(hitId);
        } else {
          _panStart = d.focalPoint;
          _panStartPan = _pan;
          _startScale = _scale;
          widget.onNodeTap(null);
        }
      },
      onScaleUpdate: (d) {
        if (_draggedNode != null) {
          final canvasPos = (d.localFocalPoint - _pan) / _scale;
          setState(() {
            _draggedNode!.x = canvasPos.dx;
            _draggedNode!.y = canvasPos.dy;
            _draggedNode!.vx = 0;
            _draggedNode!.vy = 0;
          });
        } else {
          setState(() {
            _scale = (_startScale * d.scale).clamp(0.05, 5.0);
            if (_panStart != null && _panStartPan != null) {
              _pan = _panStartPan! + (d.focalPoint - _panStart!);
            }
          });
        }
      },
      onScaleEnd: (d) {
        if (_draggedNode != null) {
          // Gently re-heat the simulation so it rearranges around the new position
          // without exploding the entire graph
          setState(() {
            _ticks = math.max(0, _ticks - 100); 
            _settled = false;
          });
          if (!_ticker.isAnimating) _ticker.repeat();
        }
        _draggedNode = null;
        _panStart = null;
      },
      child: MouseRegion(
        onHover: (e) {
          final h = _hitTest(e.localPosition);
          if (h != _hoveredId) {
            setState(() {
              _hoveredId = h;
            });
          }
        },
        onExit: (_) => setState(() {
          _hoveredId = null;
        }),
        cursor: _hoveredId != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.grab,
        child: Container(
          color: AppColors.background,
          child: ClipRect(
            child: CustomPaint(
              painter: _ObsidianPainter(
                  layouts: _layouts,
                  edges: widget.edges,
                  hiddenCommunities: widget.hiddenCommunities,
                  searchLower: searchLower,
                  selectedId: widget.selectedId,
                  hoveredId: _hoveredId,
                  scale: _scale,
                  pan: _pan,
                  showLabels: widget.showLabels,
                  nodeSize: widget.nodeSize,
                  linkThickness: widget.linkThickness,
                  showArrows: widget.showArrows),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  String? _hitTest(Offset local) {
    if (!_scale.isFinite || _scale == 0) return null;
    final canvasPos = (local - _pan) / _scale;
    for (final l in _layouts.reversed) {
      final r = _nodeRadius(l.node) + 5;
      final dx = canvasPos.dx - l.x, dy = canvasPos.dy - l.y;
      if (dx * dx + dy * dy <= r * r) return l.node.id;
    }
    return null;
  }

  double _nodeRadius(KGNode node) =>
      (math.sqrt(node.degree.toDouble()) * 2 + 4).clamp(5, 22);
}

class _ObsidianPainter extends CustomPainter {
  final List<_NodeLayout> layouts;
  final List<KGEdge> edges;
  final List<int> hiddenCommunities;
  final String searchLower;
  final String? selectedId, hoveredId;
  final double scale;
  final Offset pan;
  final bool showLabels;
  final double nodeSize;
  final double linkThickness;
  final bool showArrows;

  const _ObsidianPainter({
    required this.layouts,
    required this.edges,
    required this.hiddenCommunities,
    required this.searchLower,
    this.selectedId,
    this.hoveredId,
    required this.scale,
    required this.pan,
    required this.showLabels,
    required this.nodeSize,
    required this.linkThickness,
    required this.showArrows,
  });

  Offset _p(double x, double y) =>
      Offset(x * scale + pan.dx, y * scale + pan.dy);

  double _r(KGNode n) =>
      (math.sqrt(n.degree.toDouble()) * 1.8 + 3.5).clamp(3.5, 18) * scale;

  Color _nodeColor(KGNode n) =>
      AppColors.communityColors[n.community % AppColors.communityColors.length];

  @override
  void paint(Canvas canvas, Size size) {
    if (!scale.isFinite || scale < 0.01) return;

    final byId = <String, _NodeLayout>{for (var l in layouts) l.node.id: l};

    for (final edge in edges) {
      final a = byId[edge.source], b = byId[edge.target];
      if (a == null || b == null) continue;
      if (hiddenCommunities.contains(a.node.community) ||
          hiddenCommunities.contains(b.node.community)) continue;

      final isHighlighted = (selectedId != null && (edge.source == selectedId || edge.target == selectedId)) ||
                           (hoveredId != null && (edge.source == hoveredId || edge.target == hoveredId));
      
      // Obsidian-style subtle edges: visible but faded by default
      final opacity = searchLower.isNotEmpty
          ? 0.03
          : isHighlighted
              ? 0.9  // Strong highlight
              : 0.22; // Visible but subtle by default

      if (!a.x.isFinite || !a.y.isFinite || !b.x.isFinite || !b.y.isFinite)
        continue;

      final posA = _p(a.x, a.y);
      final posB = _p(b.x, b.y);

      final edgeColor = isHighlighted 
          ? AppColors.accent 
          : Colors.white.withOpacity(0.12); // Softer white-fade for base edges

      // Obsidian Style: Very thin, subtle lines
      final paint = Paint()
        ..color = (isHighlighted ? AppColors.accent : Colors.white.withOpacity(0.5))
            .withOpacity(opacity)
        ..strokeWidth = (isHighlighted ? (1.2 * scale) : (0.4 * scale)) * linkThickness
        ..style = PaintingStyle.stroke;

      canvas.drawLine(posA, posB, paint);

      // Arrow Head
      if (showArrows && (scale > 0.4 || isHighlighted)) {
        _drawArrow(canvas, posA, posB, (isHighlighted ? AppColors.accent : AppColors.border).withOpacity(opacity), scale * linkThickness);
      }

      // Relationship label: Only show when highlighted for a cleaner 'Obsidian' aesthetic
      if (isHighlighted && edge.type != 'direct' && !edge.type.toLowerCase().contains('wikilink')) {
        final label = edge.type.replaceAll('[[', '').replaceAll(']]', '').trim();
        if (label.isNotEmpty) {
          final mid = (posA + posB) / 2;
          _drawText(canvas, mid, label, (10 * scale).clamp(8, 14), AppColors.accent);
        }
      }
    }

    for (final l in layouts) {
      if (hiddenCommunities.contains(l.node.community)) continue;
      if (!l.x.isFinite || !l.y.isFinite) continue;
      final pos = _p(l.x, l.y);
      final r = _r(l.node);
      final color = _nodeColor(l.node);
      final isSelected = l.node.id == selectedId;
      final isHovered = l.node.id == hoveredId;
      final matchesSearch = searchLower.isEmpty ||
          l.node.label.toLowerCase().contains(searchLower);
      final opacity = matchesSearch ? 1.0 : 0.1;

      if (isSelected) {
        canvas.drawCircle(
            pos,
            r + 5 * scale,
            Paint()
              ..color = color.withOpacity(0.15)
              ..style = PaintingStyle.fill);
      }
      canvas.drawCircle(
          pos,
          r * nodeSize,
          Paint()
            ..color = color.withOpacity(opacity * 0.9)
            ..style = PaintingStyle.fill);
      
      // Only draw stroke if selected or hovered, otherwise use a very subtle one or none
      if (isSelected || isHovered) {
        canvas.drawCircle(
            pos,
            r * nodeSize,
            Paint()
              ..color = color.withOpacity(opacity)
              ..strokeWidth = 1.5 * scale
              ..style = PaintingStyle.stroke);
      } else {
        canvas.drawCircle(
            pos,
            r * nodeSize,
            Paint()
              ..color = Colors.white.withOpacity(opacity * 0.1)
              ..strokeWidth = 0.5 * scale
              ..style = PaintingStyle.stroke);
      }

      final showLabel = showLabels &&
          (isSelected || isHovered || (scale > 0.7 && matchesSearch));
      if (showLabel && l.node.label.isNotEmpty) {
        final maxLen = 22;
        final label = l.node.label.length > maxLen
            ? '${l.node.label.substring(0, maxLen)}...'
            : l.node.label;
        final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  color: isSelected
                      ? color
                      : Colors.white.withOpacity(opacity * 0.85),
                  fontSize: (11 * scale).clamp(7, 15),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos + Offset(-tp.width / 2, r + 4 * scale));
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset p1, Offset p2, Color color, double scale) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 10) return;
    
    final ux = dx / d, uy = dy / d;
    final r = 18 * scale; // Approx node radius on screen
    final tip = Offset(p2.dx - ux * r, p2.dy - uy * r);
    
    final al = (8 * scale).clamp(4.0, 12.0);
    final aa = 0.5; // Angle
    
    final ap = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - al * (ux * math.cos(aa) - uy * math.sin(aa)),
          tip.dy - al * (uy * math.cos(aa) + ux * math.sin(aa)))
      ..lineTo(tip.dx - al * (ux * math.cos(-aa) - uy * math.sin(-aa)),
          tip.dy - al * (uy * math.cos(-aa) + ux * math.sin(-aa)))
      ..close();
    
    canvas.drawPath(ap, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawText(Canvas canvas, Offset pos, String text, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _FloatingNodeInfo extends ConsumerStatefulWidget {
  final KGNode node;
  final VoidCallback onClose;
  const _FloatingNodeInfo({required this.node, required this.onClose});

  @override
  ConsumerState<_FloatingNodeInfo> createState() => _FloatingNodeInfoState();
}

class _FloatingNodeInfoState extends ConsumerState<_FloatingNodeInfo> {
  Offset _pos = const Offset(80, 60);

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final color = AppColors.communityColors[node.community % AppColors.communityColors.length];
    
    return Positioned(
      top: _pos.dy,
      left: _pos.dx,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _pos += d.delta),
        behavior: HitTestBehavior.opaque,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF1F2937) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator, size: 14, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Text(
                        'Node Details', 
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, 
                          fontSize: 14, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                        child: Text(node.contentType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Properties', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _MiroRow(label: 'Name', value: node.label),
                      _MiroRow(label: 'Cluster', value: '#${node.community}'),
                      _MiroRow(label: 'Degree', value: '${node.degree} connections'),
                      const SizedBox(height: 16),
                      const Text('Connected', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
                            child: Text('Cluster ${node.community}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.withOpacity(0.3))),
                            child: const Text('Entity', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            ref.read(vaultProvider.notifier).selectNoteById(node.id);
                            context.push('/vault');
                          },
                          child: const Text('Open in Vault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiroRow extends StatelessWidget {
  final String label, value;
  const _MiroRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11))),
        Expanded(child: Text(value, style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87, 
          fontSize: 11, 
          fontWeight: FontWeight.w500
        ))),
      ],
    ),
  );
}

// ── Obsidian-style Graph Controls ───────────────────────────────────────────
class _GraphSidebarControls extends StatelessWidget {
  final GraphState state;
  final GraphNotifier notifier;

  const _GraphSidebarControls({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Filters', isDark: isDark),
          _ToggleRow(label: 'Tags', value: false, onChanged: (v) {}, isDark: isDark),
          _ToggleRow(label: 'Attachments', value: false, onChanged: (v) {}, isDark: isDark),
          _ToggleRow(label: 'Existing files', value: false, onChanged: (v) {}, isDark: isDark),
          _ToggleRow(label: 'Orphans', value: false, onChanged: (v) {}, isDark: isDark),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Display', isDark: isDark),
          _ToggleRow(label: 'Arrows', value: state.showArrows, onChanged: (v) => notifier.toggleArrows(), isDark: isDark),
          _SliderRow(
            label: 'Node size',
            value: state.nodeSize,
            min: 0.1,
            max: 10.0,
            onChanged: notifier.setNodeSize,
            isDark: isDark,
          ),
          _SliderRow(
            label: 'Link thickness',
            value: state.linkThickness,
            min: 0.1,
            max: 5.0,
            onChanged: notifier.setLinkThickness,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Forces', isDark: isDark),
          _SliderRow(
            label: 'Center force',
            value: state.centerForce,
            min: 0.0,
            max: 0.2,
            onChanged: notifier.setCenterForce,
            isDark: isDark,
          ),
          _SliderRow(
            label: 'Repel force',
            value: state.repelForce,
            min: -100000.0,
            max: -100.0,
            onChanged: notifier.setRepelForce,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => notifier.load(source: state.activeSource),
              child: const Text('Animate', style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1)),
      );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value, isDark;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged, required this.isDark});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11)),
          Transform.scale(
            scale: 0.6,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.accent,
            ),
          ),
        ],
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final bool isDark;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged, required this.isDark});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: AppColors.accent,
              inactiveColor: isDark ? Colors.white12 : Colors.black12,
              onChanged: onChanged,
            ),
          ),
        ],
      );
}

class _NodeInfo extends StatelessWidget {
  final KGNode node;
  const _NodeInfo({required this.node});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SELECTED NODE',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(node.label,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _Row('Type', node.contentType),
        _Row('Community', '${node.community}'),
        _Row('Connections', '${node.degree}'),
        if (node.source != null && node.source!.isNotEmpty)
          _Row(
              'Source',
              node.source!.length > 30
                  ? '...${node.source!.substring(node.source!.length - 28)}'
                  : node.source!),
      ]));
}

class _CommunityInfo extends StatelessWidget {
  final KGCommunity community;
  const _CommunityInfo({required this.community});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CLUSTER INFO',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(community.name,
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
            community.summary.isEmpty
                ? 'Analyzing cluster content...'
                : community.summary,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11, height: 1.5)),
        const SizedBox(height: 12),
        _Row('Nodes', '${community.nodeCount}'),
        _Row('Community ID', '${community.id}'),
      ]));
}

class _Row extends StatelessWidget {
  final String k, v;
  const _Row(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        Flexible(
            child: Text(v,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11))),
      ]));
}

class _EmptyGraph extends StatelessWidget {
  final VoidCallback onIngest;
  const _EmptyGraph({required this.onIngest});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.hub_outlined,
                size: 48, color: AppColors.accent)),
        const SizedBox(height: 20),
        const Text('Empty Knowledge Graph',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Ingest documents to populate your knowledge graph',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Ingest Files'),
            onPressed: onIngest),
      ]));
}

class _ErrorGraph extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorGraph({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.accentRed)),
        const SizedBox(height: 20),
        const Text('Graph Unavailable',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            onPressed: onRetry,
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed)),
      ]));
}
