import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';

class CodeFlowColors {
  static const Color backgroundMain = Color(0xFF18181B);
  static const Color backgroundSidebar = Color(0xFF202022);
  static const Color backgroundSurface = Color(0xFF27272A);
  static const Color backgroundInput = Color(0xFF3F3F46);
  static const Color borderDefault = Color(0xFF3F3F46);
  static const Color borderHover = Color(0xFF52525B);
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textTertiary = Color(0xFF71717A);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentBlueHover = Color(0xFF2563EB);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentYellow = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color surface = Color(0xFF27272A);
  static const Color surfaceVariant = Color(0xFF27272A);
  static const Color background = Color(0xFF18181B);
  static const Color border = Color(0xFF3F3F46);
  static const Color textMuted = Color(0xFF71717A);
}


// ── Models ────────────────────────────────────────────────────────────────────
class CodeNode {
  final String id, name, kind, language, path, docstring;
  final int lineStart, lineEnd, complexity, loc;
  final double healthScore;
  const CodeNode(
      {required this.id,
      required this.name,
      required this.kind,
      required this.language,
      required this.path,
      this.docstring = '',
      this.lineStart = 0,
      this.lineEnd = 0,
      this.complexity = 1,
      this.loc = 0,
      this.healthScore = 100});
  factory CodeNode.fromJson(Map j) => CodeNode(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      kind: j['kind'] ?? 'file',
      language: j['language'] ?? '',
      path: j['path'] ?? '',
      docstring: j['docstring'] ?? '',
      lineStart: j['line_start'] ?? 0,
      lineEnd: j['line_end'] ?? 0,
      complexity: j['complexity'] ?? 1,
      loc: j['loc'] ?? 0,
      healthScore: (j['health_score'] ?? 100).toDouble());
}

class ProjectAnalysis {
  final List<CodeNode> nodes;
  final List<Map<String, dynamic>> edges;
  final Map<String, dynamic> stats;
  final double healthScore;
  final String projectPath;
  const ProjectAnalysis(
      {this.nodes = const [],
      this.edges = const [],
      this.stats = const {},
      this.healthScore = 100,
      this.projectPath = ''});
  factory ProjectAnalysis.fromJson(Map j) => ProjectAnalysis(
      nodes: (j['nodes'] as List? ?? [])
          .map((n) => CodeNode.fromJson(n as Map))
          .toList(),
      edges: List<Map<String, dynamic>>.from(j['edges'] as List? ?? []),
      stats: Map<String, dynamic>.from(j['stats'] as Map? ?? {}),
      healthScore: (j['health_score'] ?? 100).toDouble(),
      projectPath: j['project_path'] ?? '');
}

// ── State ─────────────────────────────────────────────────────────────────────
class CodeFlowState {
  final ProjectAnalysis? analysis;
  final bool loading;
  final String? selectedNodeId;
  final String? explanation;
  final bool loadingExplanation;
  final String filterKind, filterLang;
  const CodeFlowState(
      {this.analysis,
      this.loading = false,
      this.selectedNodeId,
      this.explanation,
      this.loadingExplanation = false,
      this.filterKind = 'all',
      this.filterLang = 'all'});
  CodeFlowState copyWith(
          {ProjectAnalysis? analysis,
          bool? loading,
          String? selectedNodeId,
          String? explanation,
          bool? loadingExplanation,
          String? filterKind,
          String? filterLang}) =>
      CodeFlowState(
          analysis: analysis ?? this.analysis,
          loading: loading ?? this.loading,
          selectedNodeId: selectedNodeId ?? this.selectedNodeId,
          explanation: explanation ?? this.explanation,
          loadingExplanation: loadingExplanation ?? this.loadingExplanation,
          filterKind: filterKind ?? this.filterKind,
          filterLang: filterLang ?? this.filterLang);
}

class CodeFlowNotifier extends StateNotifier<CodeFlowState> {
  CodeFlowNotifier() : super(const CodeFlowState());
  final _dio = apiDio;

  Future<void> analyzeProject(String path) async {
    state = state.copyWith(loading: true, analysis: null, explanation: null);
    try {
      final r =
          await _dio.post(ApiConstants.codeflowAnalyze, data: {'path': path});
      state = state.copyWith(
          analysis: ProjectAnalysis.fromJson(r.data as Map), loading: false);
    } catch (e) {
      state = state.copyWith(loading: false);
    }
  }

  void selectNode(String? id) => state = state.copyWith(selectedNodeId: id);
  void setFilterKind(String k) => state = state.copyWith(filterKind: k);
  void setFilterLang(String l) => state = state.copyWith(filterLang: l);

  Future<void> explainNode(String filePath) async {
    state = state.copyWith(loadingExplanation: true, explanation: null);
    try {
      final r = await _dio
          .post(ApiConstants.codeflowExplain, data: {'file_path': filePath});
      state = state.copyWith(
          explanation: r.data['explanation'] as String?,
          loadingExplanation: false);
    } catch (e) {
      state =
          state.copyWith(explanation: 'Error: $e', loadingExplanation: false);
    }
  }
}

final codeFlowProvider = StateNotifierProvider<CodeFlowNotifier, CodeFlowState>(
    (_) => CodeFlowNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────
class CodeFlowScreen extends ConsumerStatefulWidget {
  const CodeFlowScreen({super.key});
  @override
  ConsumerState<CodeFlowScreen> createState() => _CodeFlowScreenState();
}

class _CodeFlowScreenState extends ConsumerState<CodeFlowScreen> {
  final _pathController = TextEditingController();
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(codeFlowProvider);
    final notifier = ref.read(codeFlowProvider.notifier);
    final selected = s.selectedNodeId != null
        ? s.analysis?.nodes.firstWhere((n) => n.id == s.selectedNodeId,
            orElse: () => const CodeNode(
                id: '', name: '', kind: '', language: '', path: ''))
        : null;

    return Column(children: [
      // Header
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: CodeFlowColors.surface,
        child: Row(children: [
          const Icon(Icons.code_outlined,
              color: CodeFlowColors.accentPurple, size: 18),
          const SizedBox(width: 8),
          const Text('CodeFlow',
              style: TextStyle(
                  color: CodeFlowColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          if (s.analysis != null) ...[
            const SizedBox(width: 12),
            _HealthBadge(s.analysis!.healthScore),
            const SizedBox(width: 8),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: CodeFlowColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${s.analysis!.nodes.length} nodes',
                    style: const TextStyle(
                        color: CodeFlowColors.textSecondary, fontSize: 11))),
          ],
          const Spacer(),
          SizedBox(
              width: 280,
              child: TextField(
                controller: _pathController,
                style:
                    const TextStyle(color: CodeFlowColors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(
                    hintText: '/path/to/project',
                    isDense: true,
                    prefixIcon: Icon(Icons.folder_outlined, size: 14),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onSubmitted: notifier.analyzeProject,
              )),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: s.loading
                ? null
                : () => notifier.analyzeProject(_pathController.text),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                backgroundColor: CodeFlowColors.accentPurple),
            child: s.loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Analyze', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: s.analysis == null
            ? _EmptyCodeFlow(
                onAnalyze: () => notifier.analyzeProject(_pathController.text))
            : Row(children: [
                // File tree / node list
                Container(
                  width: 260,
                  decoration: const BoxDecoration(
                      color: CodeFlowColors.surface,
                      border:
                          Border(right: BorderSide(color: CodeFlowColors.border))),
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(
                              color: CodeFlowColors.textPrimary, fontSize: 12),
                          decoration: const InputDecoration(
                              hintText: 'Filter files...',
                              isDense: true,
                              prefixIcon: Icon(Icons.search, size: 14),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6)),
                        )),
                    _FilterRow(state: s, notifier: notifier),
                    Expanded(
                        child: _NodeList(
                            nodes: s.analysis!.nodes,
                            search: _search,
                            filterKind: s.filterKind,
                            filterLang: s.filterLang,
                            selectedId: s.selectedNodeId,
                            onSelect: notifier.selectNode)),
                  ]),
                ),
                // Main content
                Expanded(
                    child: selected != null && selected.id.isNotEmpty
                        ? _NodeDetail(
                            node: selected, state: s, notifier: notifier)
                        : _ProjectOverview(analysis: s.analysis!)),
              ]),
      ),
    ]);
  }
}

class _HealthBadge extends StatelessWidget {
  final double score;
  const _HealthBadge(this.score);
  @override
  Widget build(BuildContext context) {
    final color = score > 80
        ? CodeFlowColors.accentGreen
        : score > 60
            ? CodeFlowColors.accentYellow
            : CodeFlowColors.accentRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.favorite_outline, size: 11, color: color),
        const SizedBox(width: 4),
        Text('${score.toStringAsFixed(0)}%',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final CodeFlowState state;
  final CodeFlowNotifier notifier;
  const _FilterRow({required this.state, required this.notifier});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        Expanded(
            child: DropdownButton<String>(
          value: state.filterKind,
          isExpanded: true,
          style: const TextStyle(color: CodeFlowColors.textSecondary, fontSize: 11),
          dropdownColor: CodeFlowColors.surfaceVariant,
          underline: const SizedBox(),
          items: const ['all', 'file', 'class', 'function']
              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
              .toList(),
          onChanged: (v) {
            if (v != null) notifier.setFilterKind(v);
          },
        )),
        const SizedBox(width: 8),
        Expanded(
            child: DropdownButton<String>(
          value: state.filterLang,
          isExpanded: true,
          style: const TextStyle(color: CodeFlowColors.textSecondary, fontSize: 11),
          dropdownColor: CodeFlowColors.surfaceVariant,
          underline: const SizedBox(),
          items: const ['all', 'python', 'dart', 'javascript', 'typescript']
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: (v) {
            if (v != null) notifier.setFilterLang(v);
          },
        )),
      ]),
    );
  }
}

class _NodeList extends StatelessWidget {
  final List<CodeNode> nodes;
  final String search, filterKind, filterLang;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  const _NodeList(
      {required this.nodes,
      required this.search,
      required this.filterKind,
      required this.filterLang,
      required this.selectedId,
      required this.onSelect});

  static const _kindIcons = {
    'file': Icons.description_outlined,
    'class': Icons.class_outlined,
    'function': Icons.functions_outlined,
    'module': Icons.folder_outlined
  };
  static const _langColors = {
    'python': Color(0xFF3572A5),
    'dart': Color(0xFF00B4AB),
    'javascript': Color(0xFFF7DF1E),
    'typescript': Color(0xFF3178C6)
  };

  @override
  Widget build(BuildContext context) {
    final filtered = nodes.where((n) {
      if (search.isNotEmpty &&
          !n.name.toLowerCase().contains(search.toLowerCase()) &&
          !n.path.toLowerCase().contains(search.toLowerCase())) return false;
      if (filterKind != 'all' && n.kind != filterKind) return false;
      if (filterLang != 'all' && n.language != filterLang) return false;
      return true;
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final n = filtered[i];
        final isSelected = n.id == selectedId;
        final langColor = _langColors[n.language] ?? CodeFlowColors.textMuted;
        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: CodeFlowColors.accent.withOpacity(0.1),
          leading: Icon(_kindIcons[n.kind] ?? Icons.circle,
              size: 15,
              color: isSelected ? CodeFlowColors.accent : CodeFlowColors.textSecondary),
          title: Text(n.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color:
                      isSelected ? CodeFlowColors.accent : CodeFlowColors.textPrimary)),
          subtitle: Text(n.path,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: CodeFlowColors.textMuted)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: langColor)),
            const SizedBox(width: 4),
            _HealthDot(n.healthScore),
          ]),
          onTap: () => onSelect(n.id),
        );
      },
    );
  }
}

class _HealthDot extends StatelessWidget {
  final double score;
  const _HealthDot(this.score);
  @override
  Widget build(BuildContext context) {
    final c = score > 80
        ? CodeFlowColors.accentGreen
        : score > 60
            ? CodeFlowColors.accentYellow
            : CodeFlowColors.accentRed;
    return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c));
  }
}

class _NodeDetail extends StatelessWidget {
  final CodeNode node;
  final CodeFlowState state;
  final CodeFlowNotifier notifier;
  const _NodeDetail(
      {required this.node, required this.state, required this.notifier});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(node.name,
                        style: const TextStyle(
                            color: CodeFlowColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(node.path,
                        style: const TextStyle(
                            color: CodeFlowColors.textMuted, fontSize: 12)),
                  ])),
              _HealthBadge(node.healthScore),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Explain', style: TextStyle(fontSize: 12)),
                onPressed: state.loadingExplanation
                    ? null
                    : () => notifier.explainNode(node.path),
                style: ElevatedButton.styleFrom(
                    backgroundColor: CodeFlowColors.accentPurple),
              ),
            ]),
            const SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _InfoChip('Kind', node.kind),
              _InfoChip('Language', node.language),
              _InfoChip('Lines', '${node.lineStart}-${node.lineEnd}'),
              _InfoChip('LOC', '${node.loc}'),
              _InfoChip('Complexity', '${node.complexity}'),
            ]),
            if (node.docstring.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Documentation',
                  style: TextStyle(
                      color: CodeFlowColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: CodeFlowColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CodeFlowColors.border)),
                  child: Text(node.docstring,
                      style: const TextStyle(
                          color: CodeFlowColors.textSecondary, fontSize: 12))),
            ],
            if (state.loadingExplanation) ...[
              const SizedBox(height: 20),
              const Center(
                  child:
                      CircularProgressIndicator(color: CodeFlowColors.accentPurple)),
            ] else if (state.explanation != null) ...[
              const SizedBox(height: 20),
              const Text('AI Explanation',
                  style: TextStyle(
                      color: CodeFlowColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: CodeFlowColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: CodeFlowColors.accentPurple.withOpacity(0.3))),
                  child: Text(state.explanation!,
                      style: const TextStyle(
                          color: CodeFlowColors.textPrimary,
                          fontSize: 13,
                          height: 1.6))),
            ],
          ],
        ));
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: CodeFlowColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: CodeFlowColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: const TextStyle(color: CodeFlowColors.textMuted, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: CodeFlowColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]));
}

class _ProjectOverview extends StatelessWidget {
  final ProjectAnalysis analysis;
  const _ProjectOverview({required this.analysis});
  static const _langColors = {
    'python': Color(0xFF3572A5),
    'dart': Color(0xFF00B4AB),
    'javascript': Color(0xFFF7DF1E),
    'typescript': Color(0xFF3178C6),
    'go': Color(0xFF00ADD8),
    'rust': Color(0xFFDEA584)
  };
  @override
  Widget build(BuildContext context) {
    final stats = analysis.stats;
    final langs = Map<String, dynamic>.from(stats['languages'] as Map? ?? {});
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _StatCard('Files', '${stats['total_files'] ?? 0}',
                  Icons.description_outlined, CodeFlowColors.accent),
              const SizedBox(width: 12),
              _StatCard('Lines', '${stats['total_loc'] ?? 0}',
                  Icons.format_list_numbered, CodeFlowColors.accentPurple),
              const SizedBox(width: 12),
              _StatCard(
                  'Avg Complexity',
                  '${(stats['avg_complexity'] as num?)?.toStringAsFixed(1) ?? 0}',
                  Icons.auto_graph,
                  CodeFlowColors.accentOrange),
              const SizedBox(width: 12),
              _StatCard(
                  'Health',
                  '${analysis.healthScore.toStringAsFixed(0)}%',
                  Icons.favorite_outline,
                  analysis.healthScore > 80
                      ? CodeFlowColors.accentGreen
                      : CodeFlowColors.accentYellow),
            ]),
            const SizedBox(height: 24),
            const Text('Languages',
                style: TextStyle(
                    color: CodeFlowColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            ...langs.entries.map((e) {
              final total = langs.values.fold<int>(0, (a, b) => a + (b as int));
              final pct = total > 0 ? (e.value as int) / total : 0.0;
              final color = _langColors[e.key] ?? CodeFlowColors.textMuted;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color)),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 100,
                        child: Text(e.key,
                            style: const TextStyle(
                                color: CodeFlowColors.textSecondary, fontSize: 12))),
                    Expanded(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: CodeFlowColors.surfaceVariant,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color)))),
                    const SizedBox(width: 8),
                    Text('${e.value} files',
                        style: const TextStyle(
                            color: CodeFlowColors.textMuted, fontSize: 11)),
                  ]));
            }),
          ],
        ));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(height: 8),
                    Text(value,
                        style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: const TextStyle(
                            color: CodeFlowColors.textSecondary, fontSize: 11)),
                  ]))));
}

class _EmptyCodeFlow extends StatelessWidget {
  final VoidCallback onAnalyze;
  const _EmptyCodeFlow({required this.onAnalyze});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: CodeFlowColors.accentPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.code_outlined,
                size: 48, color: CodeFlowColors.accentPurple)),
        const SizedBox(height: 20),
        const Text('CodeFlow',
            style: TextStyle(
                color: CodeFlowColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'Enter a project path above and click Analyze\nto visualize code structure and health.',
            textAlign: TextAlign.center,
            style: TextStyle(color: CodeFlowColors.textSecondary, fontSize: 13)),
      ]));
}
