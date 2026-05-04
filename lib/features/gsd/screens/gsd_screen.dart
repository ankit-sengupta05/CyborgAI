import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class GSDStep {
  final String id, title, description, type, phase, status, output;
  final int order, estimatedMinutes;
  final List<String> dependsOn;
  const GSDStep(
      {required this.id,
      required this.title,
      this.description = '',
      this.type = 'task',
      this.phase = '',
      this.status = 'pending',
      this.output = '',
      this.order = 0,
      this.estimatedMinutes = 5,
      this.dependsOn = const []});
  factory GSDStep.fromJson(Map j) => GSDStep(
      id: j['id'] ?? '',
      title: j['title'] ?? '',
      description: j['description'] ?? '',
      type: j['type'] ?? 'task',
      phase: j['phase'] ?? '',
      status: j['status'] ?? 'pending',
      output: j['output'] ?? '',
      order: j['order'] ?? 0,
      estimatedMinutes: j['estimated_minutes'] ?? 5,
      dependsOn: List<String>.from(j['depends_on'] as List? ?? []));
}

class GSDPhaseData {
  final String id, name, description, status;
  final List<GSDStep> steps;
  final int done, total;
  const GSDPhaseData(
      {required this.id,
      required this.name,
      this.description = '',
      this.status = 'pending',
      this.steps = const [],
      this.done = 0,
      this.total = 0});
  factory GSDPhaseData.fromJson(Map j) => GSDPhaseData(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      description: j['description'] ?? '',
      status: j['status'] ?? 'pending',
      steps: (j['steps'] as List? ?? [])
          .map((s) => GSDStep.fromJson(s as Map))
          .toList(),
      done: j['done'] ?? 0,
      total: j['total'] ?? 0);
  double get progress => total == 0 ? 0 : done / total;
}

class GSDPlan {
  final String id, projectName, status, currentStepId;
  final double progressPct;
  final List<GSDPhaseData> phases;
  const GSDPlan(
      {required this.id,
      required this.projectName,
      this.status = 'planned',
      this.currentStepId = '',
      this.progressPct = 0,
      this.phases = const []});
  factory GSDPlan.fromJson(Map j) => GSDPlan(
      id: j['plan_id'] ?? j['id'] ?? '',
      projectName: j['project_name'] ?? '',
      status: j['status'] ?? 'planned',
      currentStepId: j['current_step_id'] ?? '',
      progressPct: (j['progress_pct'] ?? 0).toDouble(),
      phases: (j['phases'] as List? ?? [])
          .map((p) => GSDPhaseData.fromJson(p as Map))
          .toList());
}

// ── State ─────────────────────────────────────────────────────────────────────
enum GSDInputMode { describe, upload }

class GSDEngineState {
  final List<GSDPlan> plans;
  final GSDPlan? activePlan;
  final String generatedPrd;
  final bool generatingPrd, parsingPrd, executing;
  final double execProgress;
  final String execLog;
  final GSDInputMode inputMode;
  final int activeTab;

  // File management
  final List<String> projectFiles;
  final String? selectedFile;
  final String? selectedFileContent;
  final bool loadingFiles;
  final bool loadingContent;

  const GSDEngineState(
      {this.plans = const [],
      this.activePlan,
      this.generatedPrd = '',
      this.generatingPrd = false,
      this.parsingPrd = false,
      this.executing = false,
      this.execProgress = 0,
      this.execLog = '',
      this.inputMode = GSDInputMode.describe,
      this.activeTab = 0,
      this.projectFiles = const [],
      this.selectedFile,
      this.selectedFileContent,
      this.loadingFiles = false,
      this.loadingContent = false});

  GSDEngineState copyWith(
          {List<GSDPlan>? plans,
          GSDPlan? activePlan,
          String? generatedPrd,
          bool? generatingPrd,
          bool? parsingPrd,
          bool? executing,
          double? execProgress,
          String? execLog,
          GSDInputMode? inputMode,
          int? activeTab,
          List<String>? projectFiles,
          String? selectedFile,
          String? selectedFileContent,
          bool? loadingFiles,
          bool? loadingContent}) =>
      GSDEngineState(
          plans: plans ?? this.plans,
          activePlan: activePlan ?? this.activePlan,
          generatedPrd: generatedPrd ?? this.generatedPrd,
          generatingPrd: generatingPrd ?? this.generatingPrd,
          parsingPrd: parsingPrd ?? this.parsingPrd,
          executing: executing ?? this.executing,
          execProgress: execProgress ?? this.execProgress,
          execLog: execLog ?? this.execLog,
          inputMode: inputMode ?? this.inputMode,
          activeTab: activeTab ?? this.activeTab,
          projectFiles: projectFiles ?? this.projectFiles,
          selectedFile: selectedFile ?? this.selectedFile,
          selectedFileContent: selectedFileContent ?? this.selectedFileContent,
          loadingFiles: loadingFiles ?? this.loadingFiles,
          loadingContent: loadingContent ?? this.loadingContent);
}

class GSDEngineNotifier extends StateNotifier<GSDEngineState> {
  GSDEngineNotifier() : super(const GSDEngineState()) {
    _loadPlans();
  }
  final _dio = apiDio;
  WebSocketChannel? _ws;

  Future<void> _loadPlans() async {
    try {
      final r = await _dio.get('${ApiConstants.gsdEngine}/plans');
      final plans = (r.data['plans'] as List)
          .map((p) => GSDPlan.fromJson(p as Map))
          .toList();
      state = state.copyWith(plans: plans);
    } catch (_) {}
  }

  Future<void> generatePRD(String description, String projectName) async {
    state = state.copyWith(generatingPrd: true, generatedPrd: '');
    try {
      final r = await _dio.post('${ApiConstants.gsdEngine}/generate-prd',
          data: {'description': description, 'project_name': projectName});
      state = state.copyWith(
          generatedPrd: r.data['prd'] as String? ?? '', generatingPrd: false);
    } catch (e) {
      state = state.copyWith(generatingPrd: false, generatedPrd: 'Error: $e');
    }
  }

  Future<GSDPlan?> parsePRD(String prd, String projectName) async {
    state = state.copyWith(parsingPrd: true);
    try {
      final r = await _dio.post('${ApiConstants.gsdEngine}/parse-prd',
          data: {'prd_content': prd, 'project_name': projectName});
      final planData = r.data as Map;
      final planId = planData['id'] as String? ?? '';
      await Future.delayed(const Duration(milliseconds: 300));
      final tree =
          await _dio.get('${ApiConstants.gsdEngine}/plans/$planId/tree');
      final plan = GSDPlan.fromJson(tree.data as Map);
      state = state.copyWith(
          parsingPrd: false,
          activePlan: plan,
          plans: [plan, ...state.plans],
          activeTab: 1);
      return plan;
    } catch (e) {
      state = state.copyWith(parsingPrd: false);
      return null;
    }
  }

  Future<GSDPlan?> uploadPRD() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'docx', 'pdf'],
      );
      if (result == null || result.files.single.path == null) return null;

      state = state.copyWith(parsingPrd: true);
      final file = result.files.single;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      final r = await _dio.post('${ApiConstants.gsdEngine}/upload-prd',
          data: formData);
      final planData = r.data as Map;
      final planId = planData['id'] as String? ?? '';

      await Future.delayed(const Duration(milliseconds: 300));
      final tree =
          await _dio.get('${ApiConstants.gsdEngine}/plans/$planId/tree');
      final plan = GSDPlan.fromJson(tree.data as Map);

      state = state.copyWith(
          parsingPrd: false,
          activePlan: plan,
          plans: [plan, ...state.plans],
          activeTab: 1);
      return plan;
    } catch (e) {
      state = state.copyWith(parsingPrd: false);
      return null;
    }
  }

  Future<void> executePlan(String planId) async {
    state = state.copyWith(executing: true, execProgress: 0, execLog: '');
    final wsUrl = 'ws://127.0.0.1:8765/api/v1/gsd-engine/plans/$planId/execute';
    _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
    try {
      await for (final data in _ws!.stream) {
        final msg = jsonDecode(data as String);
        final type = msg['type'] as String? ?? '';
        if (type == 'step_start') {
          final log = '${state.execLog}▶ ${msg['title']}\n';
          state = state.copyWith(
              execLog: log,
              execProgress: (msg['progress'] as num?)?.toDouble() ?? 0);
        } else if (type == 'step_done') {
          final status = msg['status'] == 'done' ? '✅' : '❌';
          final log = '${state.execLog}$status ${msg['title']}\n';
          state = state.copyWith(
              execLog: log,
              execProgress: (msg['progress'] as num?)?.toDouble() ?? 0);
          await _refreshPlanTree(planId);
          await loadProjectFiles(planId);
        } else if (type == 'plan_done') {
          state = state.copyWith(executing: false, execProgress: 1.0);
          await _refreshPlanTree(planId);
          await loadProjectFiles(planId);
          break;
        } else if (type == 'error') {
          state = state.copyWith(
              executing: false,
              execLog: '${state.execLog}❌ Error: ${msg['message']}\n');
          break;
        }
      }
    } catch (_) {
      state = state.copyWith(executing: false);
    }
  }

  Future<void> debugPlan(String planId) async {
    state = state.copyWith(
        executing: true,
        execLog: '${state.execLog}🔍 Starting automatic debug and fix...\n');
    try {
      final r =
          await _dio.post('${ApiConstants.gsdEngine}/plans/$planId/debug');
      final fixed = r.data['issues_fixed'] ?? 0;
      state = state.copyWith(
          executing: false,
          execLog: '${state.execLog}✅ Debug complete. Fixed $fixed issues.\n');
      await _refreshPlanTree(planId);
    } catch (e) {
      state = state.copyWith(
          executing: false, execLog: '${state.execLog}❌ Debug failed: $e\n');
    }
  }

  Future<void> _refreshPlanTree(String planId) async {
    try {
      final r = await _dio.get('${ApiConstants.gsdEngine}/plans/$planId/tree');
      final plan = GSDPlan.fromJson(r.data as Map);
      state = state.copyWith(activePlan: plan);
    } catch (_) {}
  }

  void setActivePlan(GSDPlan p) {
    state = state.copyWith(activePlan: p, activeTab: 1);
    loadProjectFiles(p.id);
  }

  void setMode(GSDInputMode m) => state = state.copyWith(inputMode: m);
  void setTab(int t) => state = state.copyWith(activeTab: t);

  Future<void> loadProjectFiles(String planId) async {
    state = state.copyWith(loadingFiles: true, projectFiles: []);
    try {
      final r = await _dio.get('${ApiConstants.gsdEngine}/plans/$planId/files');
      state = state.copyWith(
          projectFiles: List<String>.from(r.data['files'] ?? []),
          loadingFiles: false);
    } catch (_) {
      state = state.copyWith(loadingFiles: false);
    }
  }

  Future<void> loadFileContent(String planId, String path) async {
    state = state.copyWith(
        loadingContent: true, selectedFile: path, selectedFileContent: null);
    try {
      final r = await _dio.get('${ApiConstants.gsdEngine}/plans/$planId/file',
          queryParameters: {'path': path});
      state = state.copyWith(
          selectedFileContent: r.data['content'] as String?,
          loadingContent: false);
    } catch (e) {
      state = state.copyWith(
          loadingContent: false, selectedFileContent: 'Error loading file: $e');
    }
  }

  @override
  void dispose() {
    _ws?.sink.close();
    super.dispose();
  }
}

final gsdEngineProvider =
    StateNotifierProvider<GSDEngineNotifier, GSDEngineState>(
        (_) => GSDEngineNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────
class GSDScreen extends ConsumerStatefulWidget {
  const GSDScreen({super.key});
  @override
  ConsumerState<GSDScreen> createState() => _GSDScreenState();
}

class _GSDScreenState extends ConsumerState<GSDScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(
        () => ref.read(gsdEngineProvider.notifier).setTab(_tabs.index));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gsdEngineProvider);
    final n = ref.read(gsdEngineProvider.notifier);

    // Sync tab controller
    if (_tabs.index != s.activeTab && !_tabs.indexIsChanging) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _tabs.animateTo(s.activeTab));
    }

    return Column(children: [
      Container(
          color: AppColors.surface,
          child: Column(children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.task_alt_outlined,
                      color: AppColors.phaseBlue, size: 18),
                  const SizedBox(width: 8),
                  const Text('GSD Engine',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Text('Get Shit Done',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  if (s.activePlan != null) ...[
                    const Spacer(),
                    _PlanProgress(plan: s.activePlan!),
                  ],
                ])),
            TabBar(
                controller: _tabs,
                labelColor: AppColors.phaseBlue,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.phaseBlue,
                indicatorWeight: 2,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'New Project'),
                  Tab(text: 'Progress Tree'),
                  Tab(text: 'Graph Tree'),
                  Tab(text: 'Plans')
                ]),
          ])),
      const Divider(height: 1),
      Expanded(
          child: TabBarView(controller: _tabs, children: [
        _NewProjectTab(state: s, notifier: n),
        _ProgressTreeTab(s: s, n: n),
        _GraphTreeTab(plan: s.activePlan),
        _PlansTab(s: s, n: n),
      ])),
    ]);
  }
}

class _PlanProgress extends StatelessWidget {
  final GSDPlan plan;
  const _PlanProgress({required this.plan});
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(plan.projectName,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(width: 10),
        SizedBox(
            width: 100,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: plan.progressPct / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.phaseBlue)))),
        const SizedBox(width: 6),
        Text('${plan.progressPct.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: AppColors.phaseBlue,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

// ── New Project Tab ───────────────────────────────────────────────────────────
class _NewProjectTab extends ConsumerStatefulWidget {
  final GSDEngineState state;
  final GSDEngineNotifier notifier;
  const _NewProjectTab({required this.state, required this.notifier});
  @override
  ConsumerState<_NewProjectTab> createState() => _NewProjectTabState();
}

class _NewProjectTabState extends ConsumerState<_NewProjectTab> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _prdCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _prdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final n = widget.notifier;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Mode selector
          Row(children: [
            _ModeBtn('Describe Project', GSDInputMode.describe,
                Icons.edit_outlined, s, n),
            const SizedBox(width: 12),
            _ModeBtn('Upload PRD', GSDInputMode.upload,
                Icons.upload_file_outlined, s, n),
          ]),
          const SizedBox(height: 24),
          // Project name
          const Text('Project Name',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
              controller: _nameCtrl,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration:
                  const InputDecoration(hintText: 'e.g. Cyborg AI Assistant')),
          const SizedBox(height: 20),

          if (s.inputMode == GSDInputMode.describe) ...[
            const Text('Project Description',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
                controller: _descCtrl,
                maxLines: 5,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                    hintText: 'Describe what you want to build in detail...')),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                icon: s.generatingPrd
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 14),
                label: Text(
                    s.generatingPrd ? 'Generating PRD...' : 'Generate PRD',
                    style: const TextStyle(fontSize: 13)),
                onPressed: s.generatingPrd
                    ? null
                    : () => n.generatePRD(_descCtrl.text, _nameCtrl.text),
              ),
            ]),
            if (s.generatedPrd.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Generated PRD',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border)),
                  child: Scrollbar(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: MarkdownBody(
                              data: s.generatedPrd,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    height: 1.5),
                                h1: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                                h2: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ))))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: s.parsingPrd
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.account_tree_outlined, size: 14),
                label: Text(
                    s.parsingPrd
                        ? 'Building execution plan...'
                        : 'Build Execution Plan',
                    style: const TextStyle(fontSize: 13)),
                onPressed: s.parsingPrd
                    ? null
                    : () => n.parsePRD(s.generatedPrd, _nameCtrl.text),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.phaseGreen),
              ),
            ],
          ] else ...[
            const Text('Upload PRD File',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            InkWell(
              onTap: s.parsingPrd ? null : () => n.uploadPRD(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.border, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 40, color: AppColors.phaseBlue.withOpacity(0.8)),
                    const SizedBox(height: 12),
                    const Text('Browse and select your PRD',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Supports .md, .txt, .docx, .pdf',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('OR Paste PRD Content',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            TextField(
                controller: _prdCtrl,
                maxLines: 8,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace'),
                decoration: const InputDecoration(
                    hintText:
                        '# Project Name\n## Phase 1: Foundation\n- [ ] Task 1\n...')),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: s.parsingPrd
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.account_tree_outlined, size: 14),
              label: Text(s.parsingPrd ? 'Parsing...' : 'Parse & Build Plan',
                  style: const TextStyle(fontSize: 13)),
              onPressed: s.parsingPrd
                  ? null
                  : () => n.parsePRD(_prdCtrl.text, _nameCtrl.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.phaseGreen),
            ),
          ],
        ]));
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final GSDInputMode mode;
  final IconData icon;
  final GSDEngineState s;
  final GSDEngineNotifier n;
  const _ModeBtn(this.label, this.mode, this.icon, this.s, this.n);
  @override
  Widget build(BuildContext context) {
    final active = s.inputMode == mode;
    return GestureDetector(
        onTap: () => n.setMode(mode),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: active
                    ? AppColors.phaseBlue.withOpacity(0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: active
                        ? AppColors.phaseBlue.withOpacity(0.5)
                        : AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 14,
                  color:
                      active ? AppColors.phaseBlue : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: active
                          ? AppColors.phaseBlue
                          : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            ])));
  }
}

// ── Progress Tree Tab ─────────────────────────────────────────────────────────
class _ProgressTreeTab extends StatelessWidget {
  final GSDEngineState s;
  final GSDEngineNotifier n;
  const _ProgressTreeTab({required this.s, required this.n});

  static const _phaseColors = {
    0: AppColors.phaseBlue,
    1: AppColors.accentPurple,
    2: AppColors.phaseGreen,
    3: AppColors.phaseRed,
  };
  static const _statusIcons = {
    'pending': Icons.radio_button_unchecked,
    'running': Icons.play_circle_outline,
    'done': Icons.check_circle_outline,
    'failed': Icons.error_outline,
    'skipped': Icons.skip_next,
  };

  @override
  Widget build(BuildContext context) {
    if (s.activePlan == null)
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_tree_outlined, size: 48, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text('No active plan. Create a project first.',
            style: TextStyle(color: AppColors.textSecondary)),
      ]));

    final plan = s.activePlan!;
    return Column(children: [
      // Execution toolbar
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.surface,
        child: Row(children: [
          Text(plan.projectName,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: plan.status == 'done'
                      ? AppColors.accentGreen.withOpacity(0.15)
                      : plan.status == 'running'
                          ? AppColors.phaseBlue.withOpacity(0.15)
                          : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(plan.status,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: plan.status == 'done'
                          ? AppColors.accentGreen
                          : plan.status == 'running'
                              ? AppColors.phaseBlue
                              : AppColors.textMuted))),
          const Spacer(),
          if (s.executing)
            Row(children: [
              SizedBox(
                  width: 120,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: s.execProgress,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.phaseBlue)))),
              const SizedBox(width: 8),
              Text('${(s.execProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: AppColors.phaseBlue, fontSize: 11)),
            ])
          else if (plan.status != 'done')
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Execute', style: TextStyle(fontSize: 12)),
              onPressed: () => n.executePlan(plan.id),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.phaseGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.bug_report_outlined, size: 14),
              label: const Text('Run & Debug', style: TextStyle(fontSize: 12)),
              onPressed: () => n.debugPlan(plan.id),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.phaseBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
          child: Row(children: [
        // 1. Progress Tree (Phases)
        Expanded(
            flex: 1,
            child: ListView(
                padding: const EdgeInsets.all(16),
                children: plan.phases.asMap().entries.map((entry) {
                  final i = entry.key;
                  final phase = entry.value;
                  final color = _phaseColors[i % 4] ?? AppColors.accent;
                  return _PhaseTreeNode(
                      phase: phase,
                      color: color,
                      statusIcons: _statusIcons,
                      currentStepId: plan.currentStepId);
                }).toList())),

        const VerticalDivider(width: 1, color: AppColors.border),

        // 2. File Management System
        Expanded(flex: 1, child: _FileExplorer(s: s, n: n)),

        const VerticalDivider(width: 1, color: AppColors.border),

        // 3. Code Viewer
        Expanded(flex: 1, child: _CodeViewer(s: s)),

        // Execution log (collapsed into overlay or side pane if needed, but keeping for now as requested by "along with")
        if (s.execLog.isNotEmpty &&
            false) // Hidden for now to fulfill the "divide by three" request, or we can make it a floating drawer
          Container(
              width: 200,
              decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(left: BorderSide(color: AppColors.border))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('LOG',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold))),
                    const Divider(height: 1),
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Text(s.execLog,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    height: 1.4)))),
                  ])),
      ])),
    ]);
  }
}

class _FileExplorer extends StatelessWidget {
  final GSDEngineState s;
  final GSDEngineNotifier n;
  const _FileExplorer({required this.s, required this.n});

  @override
  Widget build(BuildContext context) {
    if (s.loadingFiles) return const Center(child: CircularProgressIndicator());
    if (s.projectFiles.isEmpty)
      return const Center(
          child: Text('No files found',
              style: TextStyle(color: AppColors.textMuted)));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.folder_open_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            const Text('WORKSPACE',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.refresh, size: 14),
                onPressed: () => n.loadProjectFiles(s.activePlan!.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ])),
      const Divider(height: 1),
      Expanded(
          child: ListView.builder(
        itemCount: s.projectFiles.length,
        itemBuilder: (context, index) {
          final path = s.projectFiles[index];
          final isSelected = s.selectedFile == path;
          final fileName = path.split('/').last;
          final depth = path.split('/').length - 1;

          return InkWell(
            onTap: () => n.loadFileContent(s.activePlan!.id, path),
            child: Container(
              padding: EdgeInsets.only(
                  left: 12.0 + (depth * 12), top: 6, bottom: 6, right: 12),
              color: isSelected ? AppColors.phaseBlue.withOpacity(0.1) : null,
              child: Row(children: [
                Icon(_getFileIcon(fileName),
                    size: 14,
                    color: isSelected
                        ? AppColors.phaseBlue
                        : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(fileName,
                        style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.phaseBlue
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400))),
              ]),
            ),
          );
        },
      )),
    ]);
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.dart')) return Icons.code;
    if (fileName.endsWith('.py')) return Icons.code;
    if (fileName.endsWith('.md')) return Icons.description_outlined;
    if (fileName.endsWith('.json')) return Icons.settings_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _CodeViewer extends StatelessWidget {
  final GSDEngineState s;
  const _CodeViewer({required this.s});

  @override
  Widget build(BuildContext context) {
    if (s.loadingContent)
      return const Center(child: CircularProgressIndicator());
    if (s.selectedFileContent == null)
      return const Center(
          child: Text('Select a file to view code',
              style: TextStyle(color: AppColors.textMuted)));

    final isMarkdown = s.selectedFile?.endsWith('.md') ?? false;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppColors.surfaceVariant.withOpacity(0.5),
        child: Row(children: [
          Text(s.selectedFile ?? '',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace')),
          const Spacer(),
          if (isMarkdown)
            const Icon(Icons.edit_note, size: 14, color: AppColors.textMuted),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: Container(
          width: double.infinity,
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isMarkdown
                ? MarkdownBody(
                    data: s.selectedFileContent!,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.5),
                      code: const TextStyle(
                          backgroundColor: AppColors.surfaceVariant,
                          fontFamily: 'monospace'),
                      codeblockDecoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4)),
                    ))
                : Text(s.selectedFileContent!,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4)),
          ),
        ),
      ),
    ]);
  }
}

class _PhaseTreeNode extends StatefulWidget {
  final GSDPhaseData phase;
  final Color color;
  final Map<String, IconData> statusIcons;
  final String currentStepId;
  const _PhaseTreeNode(
      {required this.phase,
      required this.color,
      required this.statusIcons,
      required this.currentStepId});
  @override
  State<_PhaseTreeNode> createState() => _PhaseTreeNodeState();
}

class _PhaseTreeNodeState extends State<_PhaseTreeNode> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final statusColor = phase.status == 'done'
        ? AppColors.accentGreen
        : phase.status == 'running'
            ? widget.color
            : AppColors.textMuted;
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Phase header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.color.withOpacity(0.25))),
                child: Row(children: [
                  Icon(_expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16, color: widget.color),
                  const SizedBox(width: 6),
                  Icon(
                      phase.status == 'done'
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(phase.name,
                          style: TextStyle(
                              color: widget.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700))),
                  Text('${phase.done}/${phase.total}',
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 60,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                              value: phase.progress,
                              minHeight: 5,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(statusColor)))),
                ])),
          ),
          // Steps
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Column(
                  children: phase.steps.map((step) {
                final isRunning = step.id == widget.currentStepId;
                final stepColor = step.status == 'done'
                    ? AppColors.accentGreen
                    : step.status == 'failed'
                        ? AppColors.accentRed
                        : isRunning
                            ? widget.color
                            : AppColors.textMuted;
                final stepIcon = isRunning
                    ? Icons.play_circle_outline
                    : widget.statusIcons[step.status] ??
                        Icons.radio_button_unchecked;
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                          width: 1,
                          height: 20,
                          color: AppColors.border,
                          margin: const EdgeInsets.only(right: 12)),
                      Icon(stepIcon, size: 14, color: stepColor),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(step.title,
                              style: TextStyle(
                                  color: stepColor,
                                  fontSize: 12,
                                  fontWeight: isRunning
                                      ? FontWeight.w600
                                      : FontWeight.w400))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(step.type,
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted))),
                    ]));
              }).toList()),
            ),
        ]));
  }
}

// ── Plans Tab ─────────────────────────────────────────────────────────────────
class _PlansTab extends StatelessWidget {
  final GSDEngineState s;
  final GSDEngineNotifier n;
  const _PlansTab({required this.s, required this.n});
  @override
  Widget build(BuildContext context) {
    if (s.plans.isEmpty)
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.list_alt_outlined, size: 48, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text('No plans yet. Create your first project.',
            style: TextStyle(color: AppColors.textSecondary)),
      ]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: s.plans.length,
      itemBuilder: (_, i) {
        final p = s.plans[i];
        final isActive = s.activePlan?.id == p.id;
        final statusColor = p.status == 'done'
            ? AppColors.accentGreen
            : p.status == 'running'
                ? AppColors.phaseBlue
                : AppColors.textMuted;
        return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              selected: isActive,
              selectedTileColor: AppColors.phaseBlue.withOpacity(0.05),
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.phaseBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.account_tree_outlined,
                      size: 18, color: AppColors.phaseBlue)),
              title: Text(p.projectName,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              subtitle: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: statusColor)),
                const SizedBox(width: 6),
                Text(p.status,
                    style: TextStyle(fontSize: 11, color: statusColor)),
                const SizedBox(width: 12),
                Text('${p.progressPct.toStringAsFixed(0)}% complete',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
              trailing: Text('${p.phases.length} phases',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              onTap: () {
                n.setActivePlan(p);
                n.setTab(1);
              },
            ));
      },
    );
  }
}

class _GraphTreeTab extends StatelessWidget {
  final GSDPlan? plan;
  const _GraphTreeTab({this.plan});

  @override
  Widget build(BuildContext context) {
    if (plan == null) return const Center(child: Text('No active plan'));
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          _GSDGraphPainter(plan: plan!),
          ListView(
            padding: const EdgeInsets.all(40),
            children:
                plan!.phases.map((p) => _GraphPhaseNode(phase: p)).toList(),
          ),
        ],
      ),
    );
  }
}

class _GSDGraphPainter extends StatelessWidget {
  final GSDPlan plan;
  const _GSDGraphPainter({required this.plan});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TreeLinePainter(),
      size: Size.infinite,
    );
  }
}

class TreeLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.border.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // Draw a vertical line represent the main trunk
    final startX = 60.0;
    canvas.drawLine(
      Offset(startX, 40),
      Offset(startX, size.height - 40),
      paint,
    );

    // Draw arrow heads along the line
    final arrowPaint = Paint()
      ..color = AppColors.border.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 15; i++) {
      double y = 80.0 + (i * 150);
      if (y > size.height - 40) break;

      // Draw arrow head pointing down
      final path = Path();
      path.moveTo(startX - 5, y - 5);
      path.lineTo(startX, y);
      path.lineTo(startX + 5, y - 5);
      canvas.drawPath(path, arrowPaint);
    }

    // Draw some branch dots
    for (var i = 0; i < 10; i++) {
      double y = 60.0 + (i * 150);
      if (y > size.height - 40) break;
      canvas.drawCircle(Offset(startX, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GraphPhaseNode extends StatelessWidget {
  final GSDPhaseData phase;
  const _GraphPhaseNode({required this.phase});

  @override
  Widget build(BuildContext context) {
    final isDone = phase.status == 'done';
    final isFailed = phase.status == 'failed';
    final isRunning = phase.status == 'running';

    final color = isFailed
        ? AppColors.phaseRed
        : isDone
            ? AppColors.accentGreen
            : isRunning
                ? AppColors.phaseBlue
                : AppColors.border;

    return Column(
      children: [
        InkWell(
          onTap: () => _showPhaseSummary(context, phase),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
                color: (isDone || isFailed)
                    ? color.withOpacity(0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: isRunning ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(isRunning ? 0.3 : 0.1),
                      blurRadius: isRunning ? 15 : 10,
                      offset: const Offset(0, 4))
                ]),
            child: Column(
              children: [
                Text(phase.name,
                    style: TextStyle(
                        color: (isDone || isFailed)
                            ? color
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 8),
                  Text(phase.status.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: phase.steps.map((s) => _GraphStepNode(step: s)).toList(),
        ),
        const SizedBox(height: 40),
        // Connection line with arrow
        Column(children: [
          Container(
              width: 2, height: 40, color: AppColors.border.withOpacity(0.5)),
          Icon(Icons.keyboard_arrow_down,
              size: 20, color: AppColors.border.withOpacity(0.5)),
        ]),
      ],
    );
  }

  void _showPhaseSummary(BuildContext context, GSDPhaseData phase) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(phase.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${phase.status}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Progress: ${phase.done}/${phase.total} tasks complete'),
            const SizedBox(height: 10),
            Text(phase.description.isNotEmpty
                ? phase.description
                : 'Detailed phase execution.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _GraphStepNode extends StatelessWidget {
  final GSDStep step;
  const _GraphStepNode({required this.step});

  @override
  Widget build(BuildContext context) {
    final isDone = step.status == 'done';
    final isFailed = step.status == 'failed';
    final isRunning = step.status == 'running';

    final color = isFailed
        ? AppColors.phaseRed
        : isDone
            ? AppColors.accentGreen
            : isRunning
                ? AppColors.phaseBlue
                : AppColors.textMuted;

    return InkWell(
      onTap: () => _showStepSummary(context, step),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: (isDone || isFailed)
                ? color.withOpacity(0.1)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  (isDone || isFailed || isRunning) ? color : AppColors.border,
              width: isRunning ? 2 : 1,
            ),
            boxShadow: isRunning
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1)
                  ]
                : []),
        child: Column(
          children: [
            Icon(
                isDone
                    ? Icons.check_circle
                    : isFailed
                        ? Icons.error
                        : isRunning
                            ? Icons.sync
                            : Icons.radio_button_unchecked,
                size: 18,
                color: color),
            const SizedBox(height: 8),
            Text(step.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: (isDone || isFailed)
                        ? AppColors.textPrimary
                        : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: (isDone || isFailed || isRunning)
                        ? FontWeight.w600
                        : FontWeight.w400)),
            if (step.type != 'task') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(step.type.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
      ),
    );
  }

  void _showStepSummary(BuildContext context, GSDStep step) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(children: [
          Icon(Icons.info_outline, color: AppColors.phaseBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(step.title, style: const TextStyle(fontSize: 16))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DESCRIPTION',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  step.description.isNotEmpty
                      ? step.description
                      : 'No description provided.',
                  style: const TextStyle(fontSize: 13)),
              if (step.output.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('OUTPUT / LOG',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(step.output,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }
}
