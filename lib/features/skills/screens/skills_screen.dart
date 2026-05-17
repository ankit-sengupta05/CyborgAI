import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final skillsProvider =
    StateNotifierProvider<SkillsNotifier, SkillsState>((ref) {
  return SkillsNotifier();
});

class SkillsState {
  final List<Map<String, dynamic>> skills;
  final bool isLoading;
  final String? error;
  final String? creationStatus;

  const SkillsState({
    this.skills = const [],
    this.isLoading = false,
    this.error,
    this.creationStatus,
  });

  SkillsState copyWith({
    List<Map<String, dynamic>>? skills,
    bool? isLoading,
    String? error,
    String? creationStatus,
  }) =>
      SkillsState(
        skills: skills ?? this.skills,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        creationStatus: creationStatus ?? this.creationStatus,
      );
}

class SkillsNotifier extends StateNotifier<SkillsState> {
  SkillsNotifier() : super(const SkillsState());

  Future<void> loadSkills() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await apiDio.get(ApiConstants.skillsList);
      final data = res.data;
      final skills = List<Map<String, dynamic>>.from(data['skills'] ?? []);
      state = state.copyWith(skills: skills, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> executeSkill(String name, Map<String, dynamic> params) async {
    try {
      final res = await apiDio.post(ApiConstants.skillsExecute, data: {
        'name': name,
        'parameters': params,
      });
      // Refresh after execution
      await loadSkills();
    } catch (e) {
      state = state.copyWith(error: 'Execution failed: $e');
    }
  }

  Future<Map<String, dynamic>?> createSkill(
      String description, String? name) async {
    state = state.copyWith(creationStatus: 'Creating skill...');
    try {
      final res = await apiDio.post(ApiConstants.skillsCreate, data: {
        'task_description': description,
        if (name != null && name.isNotEmpty) 'skill_name': name,
      });
      final result = res.data;
      if (result['success'] == true) {
        state = state.copyWith(creationStatus: 'Skill created successfully!');
        await loadSkills();
      } else {
        state = state.copyWith(
            creationStatus: 'Creation failed: ${result['error']}');
      }
      return result;
    } catch (e) {
      state = state.copyWith(creationStatus: 'Error: $e');
      return null;
    }
  }

  Future<void> deleteSkill(String name) async {
    try {
      await apiDio.delete('${ApiConstants.skillsBase}/$name');
      await loadSkills();
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete skill: $e');
    }
  }

  Future<void> autoGenerateSkills(List<String> recentQueries) async {
    state = state.copyWith(creationStatus: 'Auto-generating skills from recent activity...');
    try {
      final res = await apiDio.post(ApiConstants.skillsAutoGenerate, data: {
        'recent_queries': recentQueries,
        'context': '',
      });
      final data = res.data;
      final count = data['count'] ?? 0;
      if (count > 0) {
        state = state.copyWith(
          creationStatus: 'Auto-generated $count new skill${count == 1 ? '' : 's'}!',
        );
        await loadSkills();
      } else {
        state = state.copyWith(
          creationStatus: 'No new skills needed — all capabilities are covered.',
        );
      }
    } catch (e) {
      state = state.copyWith(creationStatus: 'Auto-generate failed: $e');
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(skillsProvider.notifier).loadSkills());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(skillsProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSidebar,
              border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI OS Skills',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${state.skills.length} skills registered',
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _ActionButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onTap: () =>
                      ref.read(skillsProvider.notifier).loadSkills(),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.auto_awesome,
                  tooltip: 'Auto-Generate Skills',
                  onTap: () => ref
                      .read(skillsProvider.notifier)
                      .autoGenerateSkills([]),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.add,
                  tooltip: 'Create Skill',
                  accent: true,
                  onTap: () => _showCreateDialog(context),
                ),
              ],
            ),
          ),

          // ── Status bar ──
          if (state.creationStatus != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: state.creationStatus!.contains('success')
                  ? AppColors.accentGreen.withOpacity(0.12)
                  : AppColors.accent.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(
                    state.creationStatus!.contains('success')
                        ? Icons.check_circle
                        : Icons.info_outline,
                    size: 14,
                    color: state.creationStatus!.contains('success')
                        ? AppColors.accentGreen
                        : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.creationStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        color: state.creationStatus!.contains('success')
                            ? AppColors.accentGreen
                            : AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Content ──
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : state.skills.isEmpty
                    ? _EmptyState(
                        onCreateTap: () => _showCreateDialog(context))
                    : _SkillsList(skills: state.skills),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final descController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Skill',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe what this skill should do. The AI will generate, test, '
                'and debug the code automatically.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Send a WhatsApp message to any contact...',
                  hintStyle:
                      const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Skill name (optional)',
                  hintStyle:
                      const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundMain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final desc = descController.text.trim();
              if (desc.isEmpty) return;
              Navigator.pop(ctx);
              ref.read(skillsProvider.notifier).createSkill(
                    desc,
                    nameController.text.trim().isEmpty
                        ? null
                        : nameController.text.trim(),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create Skill'),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.psychology_outlined,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Skills Yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Skills are auto-created when you ask the AI\nto do something new, or create one manually.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create First Skill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skills List ──────────────────────────────────────────────────────────────

class _SkillsList extends StatelessWidget {
  final List<Map<String, dynamic>> skills;
  const _SkillsList({required this.skills});

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in skills) {
      final cat = (s['category'] ?? 'general').toString();
      grouped.putIfAbsent(cat, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 12),
            child: Text(
              entry.key.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          ...entry.value.map((s) => _SkillCard(skill: s)),
        ],
      ],
    );
  }
}

// ── Skill Card ───────────────────────────────────────────────────────────────

class _SkillCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> skill;
  const _SkillCard({required this.skill});

  @override
  ConsumerState<_SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends ConsumerState<_SkillCard> {
  bool _hovered = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.skill;
    final isActive = s['is_active'] == true;
    final isAuto = s['auto_created'] == true;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.backgroundSurface
                : AppColors.backgroundSidebar,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? (_hovered
                      ? AppColors.accent.withOpacity(0.3)
                      : AppColors.border)
                  : AppColors.border.withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accent.withOpacity(0.12)
                          : AppColors.textMuted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAuto
                          ? Icons.smart_toy_outlined
                          : Icons.extension_outlined,
                      size: 16,
                      color: isActive
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (s['name'] ?? '').toString(),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration:
                                isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          (s['description'] ?? '').toString(),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isAuto)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'AUTO',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${s['use_count'] ?? 0}×',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: AppColors.textTertiary,
                    hoverColor: AppColors.accent.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(skillsProvider.notifier).deleteSkill(s['name']);
                    },
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMain,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                          label: 'Usage',
                          value: s['usage']?.toString() ?? ''),
                      if (s['parameters'] != null &&
                          (s['parameters'] as List).isNotEmpty)
                        _DetailRow(
                          label: 'Params',
                          value: (s['parameters'] as List)
                              .map((p) =>
                                  '${p['name']}(${p['type']})')
                              .join(', '),
                        ),
                      if (s['created_at'] != null)
                        _DetailRow(
                            label: 'Created',
                            value: s['created_at'].toString()),
                      if (s['last_used'] != null)
                        _DetailRow(
                            label: 'Last Used',
                            value: s['last_used'].toString()),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;
  const _ActionButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.accent = false});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.accent
                  ? (_hovered
                      ? AppColors.accent
                      : AppColors.accent.withOpacity(0.8))
                  : (_hovered
                      ? AppColors.backgroundSurface
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.accent
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
