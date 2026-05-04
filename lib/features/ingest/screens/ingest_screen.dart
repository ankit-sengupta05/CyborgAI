import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';

// ── Job model ─────────────────────────────────────────────────────────────────
enum JobType   { file, folder, youtube }
enum JobStatus { queued, running, done, failed }

class IngestJob {
  final String id;
  final String name;
  final String path;          // file path OR youtube URL
  final JobType type;
  JobStatus status;
  double progress;            // 0.0 – 1.0
  String statusText;
  int nodesCreated;
  String? error;
  DateTime startedAt;
  DateTime? finishedAt;

  IngestJob({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.status    = JobStatus.queued,
    this.progress  = 0,
    this.statusText= 'Queued',
    this.nodesCreated = 0,
    this.error,
    DateTime? startedAt,
    this.finishedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  String get eta {
    if (status == JobStatus.done || status == JobStatus.failed) return '';
    if (status == JobStatus.queued) return 'Waiting…';
    if (progress <= 0) return 'Calculating…';
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final totalEst = elapsed / progress;
    final remaining = totalEst - elapsed;
    if (remaining < 60) return '~${remaining.toStringAsFixed(0)}s';
    return '~${(remaining / 60).toStringAsFixed(1)}m';
  }

  Duration? get elapsed => finishedAt != null
      ? finishedAt!.difference(startedAt)
      : null;
}

// ── State / notifier ──────────────────────────────────────────────────────────
class IngestState {
  final List<IngestJob> jobs;
  final bool isRunning;
  final int totalNodes;
  const IngestState({this.jobs = const [], this.isRunning = false, this.totalNodes = 0});
  IngestState copyWith({List<IngestJob>? jobs, bool? isRunning, int? totalNodes}) =>
      IngestState(jobs: jobs ?? this.jobs, isRunning: isRunning ?? this.isRunning,
          totalNodes: totalNodes ?? this.totalNodes);
}

class IngestNotifier extends StateNotifier<IngestState> {
  IngestNotifier() : super(const IngestState());
  final _dio = apiDio;
  Timer? _processingTimer;
  int _idCounter = 0;

  String _nextId() => 'job_${++_idCounter}';

  void addFile(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    _add(IngestJob(id: _nextId(), name: name, path: path, type: JobType.file));
  }

  void addFolder(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    _add(IngestJob(id: _nextId(), name: name, path: path, type: JobType.folder));
  }

  void addYouTube(String url) {
    final name = url.length > 40 ? '${url.substring(0, 40)}…' : url;
    _add(IngestJob(id: _nextId(), name: name, path: url, type: JobType.youtube));
  }

  void _add(IngestJob job) {
    state = state.copyWith(jobs: [...state.jobs, job]);
    _startQueue();
  }

  void _startQueue() {
    _processingTimer?.cancel();
    _processingTimer = Timer(const Duration(milliseconds: 100), _processNext);
  }

  Future<void> _processNext() async {
    if (state.isRunning) return;
    final queued = state.jobs.where((j) => j.status == JobStatus.queued).toList();
    if (queued.isEmpty) return;

    final job = queued.first;
    _updateJob(job.id, status: JobStatus.running, statusText: 'Processing…', progress: 0.05);
    state = state.copyWith(isRunning: true);

    try {
      if (job.type == JobType.youtube) {
        await _ingestYouTube(job);
      } else {
        await _ingestPath(job);
      }
    } catch (e) {
      _updateJob(job.id, status: JobStatus.failed, statusText: 'Error', error: e.toString(), progress: 0);
    }

    state = state.copyWith(isRunning: false);
    // Process next job
    _startQueue();
  }

  Future<void> _ingestPath(IngestJob job) async {
    _updateJob(job.id, statusText: 'Sending to backend…', progress: 0.1);
    _updateJob(job.id, statusText: 'Sending to backend…', progress: 0.3);
    final resp = await _dio.post(ApiConstants.graphIngest, data: {'path': job.path});
    final nodes = resp.data['nodes_created'] as int? ?? 0;
    _updateJob(job.id,
        status: JobStatus.done, statusText: 'Done — \$nodes nodes created',
        progress: 1.0, nodesCreated: nodes,
        finishedAt: DateTime.now());
    state = state.copyWith(totalNodes: state.totalNodes + nodes);
  }

  Future<void> _ingestYouTube(IngestJob job) async {
    _updateJob(job.id, statusText: 'Extracting transcript…', progress: 0.2);
    final resp = await _dio.post(
      ApiConstants.graphIngestYT,
      data: {'url': job.path},
    );
    final nodes = resp.data['nodes_created'] as int? ?? 0;
    _updateJob(job.id,
        status: JobStatus.done, statusText: 'Done — $nodes nodes created',
        progress: 1.0, nodesCreated: nodes,
        finishedAt: DateTime.now());
    state = state.copyWith(totalNodes: state.totalNodes + nodes);
  }

  void _updateJob(String id, {
    JobStatus? status, String? statusText, double? progress,
    int? nodesCreated, String? error, DateTime? finishedAt,
  }) {
    final jobs = state.jobs.map((j) {
      if (j.id != id) return j;
      j.status        = status        ?? j.status;
      j.statusText    = statusText    ?? j.statusText;
      j.progress      = progress      ?? j.progress;
      j.nodesCreated  = nodesCreated  ?? j.nodesCreated;
      j.error         = error         ?? j.error;
      j.finishedAt    = finishedAt    ?? j.finishedAt;
      return j;
    }).toList();
    state = state.copyWith(jobs: jobs);
  }

  void removeJob(String id) {
    state = state.copyWith(jobs: state.jobs.where((j) => j.id != id).toList());
  }

  void clearCompleted() {
    state = state.copyWith(
        jobs: state.jobs.where((j) => j.status == JobStatus.queued ||
            j.status == JobStatus.running).toList());
  }

  @override
  void dispose() { _processingTimer?.cancel(); super.dispose(); }
}

final ingestProvider =
    StateNotifierProvider<IngestNotifier, IngestState>((_) => IngestNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────
class IngestScreen extends ConsumerStatefulWidget {
  const IngestScreen({super.key});
  @override ConsumerState<IngestScreen> createState() => _IngestScreenState();
}

class _IngestScreenState extends ConsumerState<IngestScreen> {
  final _urlController = TextEditingController();
  final _pathController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      final n = ref.read(ingestProvider.notifier);
      for (final f in result.files) {
        if (f.path != null) n.addFile(f.path!);
      }
    }
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      ref.read(ingestProvider.notifier).addFolder(path);
    }
  }

  void _addYouTube() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    ref.read(ingestProvider.notifier).addYouTube(url);
    _urlController.clear();
  }

  void _addManualPath() {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    ref.read(ingestProvider.notifier).addFile(path);
    _pathController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(ingestProvider);
    final notifier = ref.read(ingestProvider.notifier);

    final queued  = state.jobs.where((j) => j.status == JobStatus.queued).length;
    final running = state.jobs.where((j) => j.status == JobStatus.running).length;
    final done    = state.jobs.where((j) => j.status == JobStatus.done).length;
    final failed  = state.jobs.where((j) => j.status == JobStatus.failed).length;

    return Column(children: [
      // ── Header ─────────────────────────────────────────────────────────────
      Container(
        color: AppColors.surface,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.upload_file_outlined, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text('Ingest Manager', style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _StatPill('$queued queued', AppColors.accentYellow),
              const SizedBox(width: 6),
              if (running > 0) _StatPill('$running running', AppColors.accentGreen),
              if (done > 0)    _StatPill('$done done', AppColors.accent),
              if (failed > 0)  _StatPill('$failed failed', AppColors.accentRed),
              const Spacer(),
              if (done > 0 || failed > 0)
                TextButton(
                  onPressed: notifier.clearCompleted,
                  child: const Text('Clear completed', style: TextStyle(fontSize: 12)),
                ),
            ]),
          ),
          const Divider(height: 1),
        ]),
      ),

      Expanded(
        child: Row(children: [
          // ── Left: Add sources ──────────────────────────────────────────────
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionLabel('ADD SOURCES'),
                const SizedBox(height: 12),

                // Files button
                _AddButton(
                  icon: Icons.description_outlined,
                  label: 'Add Files',
                  subtitle: 'Pick individual files (.txt, .pdf, .md, .py …)',
                  color: AppColors.accent,
                  onTap: _pickFiles,
                ),
                const SizedBox(height: 8),

                // Folder button
                _AddButton(
                  icon: Icons.folder_outlined,
                  label: 'Add Folder',
                  subtitle: 'Recursively ingest all supported files in a folder',
                  color: AppColors.accentPurple,
                  onTap: _pickFolder,
                ),
                const SizedBox(height: 16),

                // Manual path
                const _SectionLabel('OR PASTE PATH'),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _pathController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12,
                        fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'C:\\Users\\...\\Documents',
                      isDense: true,
                      prefixIcon: Icon(Icons.folder_open, size: 14),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: (_) => _addManualPath(),
                  )),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _addManualPath,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11)),
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ]),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // YouTube URL
                _AddButton(
                  icon: Icons.play_circle_outlined,
                  label: 'YouTube Video',
                  subtitle: 'Extract transcript → knowledge graph nodes',
                  color: const Color(0xFFFF0000),
                  onTap: null, // shows the url field below
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'https://youtube.com/watch?v=...',
                      isDense: true,
                      prefixIcon: Icon(Icons.link, size: 14),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: (_) => _addYouTube(),
                  )),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _addYouTube,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11)),
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ]),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Stats
                _StatRow('Total nodes created', '${state.totalNodes}', AppColors.accent),
                const SizedBox(height: 6),
                _StatRow('Jobs completed', '$done', AppColors.accentGreen),
                _StatRow('Jobs failed', '$failed', failed > 0 ? AppColors.accentRed : AppColors.textMuted),
              ]),
            ),
          ),

          // ── Right: Job queue ───────────────────────────────────────────────
          Expanded(
            child: state.jobs.isEmpty
                ? _EmptyQueue()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.jobs.length,
                    itemBuilder: (_, i) {
                      final job = state.jobs[state.jobs.length - 1 - i]; // newest first
                      return _JobCard(job: job, onRemove: () => notifier.removeJob(job.id));
                    },
                  ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1));
}

class _StatPill extends StatelessWidget {
  final String label; final Color color;
  const _StatPill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)));
}

class _StatRow extends StatelessWidget {
  final String label, value; final Color color;
  const _StatRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]));
}

class _AddButton extends StatelessWidget {
  final IconData icon; final String label, subtitle; final Color color;
  final VoidCallback? onTap;
  const _AddButton({required this.icon, required this.label, required this.subtitle,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Icon(Icons.add_circle_outline, color: color.withOpacity(0.6), size: 18),
      ])));
}

class _JobCard extends StatelessWidget {
  final IngestJob job;
  final VoidCallback onRemove;
  const _JobCard({required this.job, required this.onRemove});

  static const _typeIcons = {
    JobType.file:    Icons.description_outlined,
    JobType.folder:  Icons.folder_outlined,
    JobType.youtube: Icons.play_circle_outlined,
  };
  static const _typeColors = {
    JobType.file:    AppColors.accent,
    JobType.folder:  AppColors.accentPurple,
    JobType.youtube: Color(0xFFFF0000),
  };
  static const _statusColors = {
    JobStatus.queued:  AppColors.textMuted,
    JobStatus.running: AppColors.accentYellow,
    JobStatus.done:    AppColors.accentGreen,
    JobStatus.failed:  AppColors.accentRed,
  };

  @override
  Widget build(BuildContext context) {
    final typeColor   = _typeColors[job.type]   ?? AppColors.accent;
    final statusColor = _statusColors[job.status] ?? AppColors.textMuted;
    final isDone   = job.status == JobStatus.done;
    final isFailed = job.status == JobStatus.failed;
    final isActive = job.status == JobStatus.running;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_typeIcons[job.type] ?? Icons.file_present, color: typeColor, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job.name, style: const TextStyle(color: AppColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(job.path, style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          // Status badge
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(job.statusText,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600))),
          const SizedBox(width: 6),
          if (isDone || isFailed)
            IconButton(icon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                onPressed: onRemove, padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20)),
        ]),

        if (isActive || (!isDone && !isFailed && job.progress > 0)) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: isActive
                ? LinearProgressIndicator(
                    value: job.progress > 0 ? job.progress : null,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accentYellow))
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text(job.statusText, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const Spacer(),
            if (job.eta.isNotEmpty)
              Text(job.eta, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ],

        if (isDone) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle_outline, color: AppColors.accentGreen, size: 14),
            const SizedBox(width: 6),
            Text('${job.nodesCreated} nodes created',
                style: const TextStyle(color: AppColors.accentGreen, fontSize: 11)),
            const Spacer(),
            if (job.elapsed != null)
              Text('in ${job.elapsed!.inSeconds}s',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ],

        if (isFailed && job.error != null) ...[
          const SizedBox(height: 8),
          Text('Error: ${job.error}',
              style: const TextStyle(color: AppColors.accentRed, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ])));
  }
}

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.upload_outlined, size: 48, color: AppColors.accent)),
    const SizedBox(height: 20),
    const Text('No ingestion jobs', style: TextStyle(color: AppColors.textPrimary,
        fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Add files, folders, or YouTube URLs\nfrom the panel on the left.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  ]));
}
