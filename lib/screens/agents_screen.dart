import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/paperclip_theme.dart';

/// Full-featured Agents screen — lists agents, shows status,
/// allows hire/pause/resume/terminate/wake.
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<Agent> _agents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final agents = await state.api.getAgents(company.id);
      if (mounted) setState(() { _agents = agents; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final company = state.selectedCompany;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Text('Agents',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (_agents.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_agents.length}',
                        style: theme.textTheme.labelSmall),
                  ),
                ],
                const Spacer(),
                if (company != null) ...[
                  TextButton.icon(
                    onPressed: () => _showAutoHireDialog(context),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Auto-Hire Team'),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _showHireDialog(context),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Hire Agent'),
                    style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: PaperclipTheme.accentGreen))
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: PaperclipTheme.accentRed)))
                    : _agents.isEmpty
                        ? _EmptyAgents(
                            onHire: () => _showHireDialog(context),
                            onAutoHire: () => _showAutoHireDialog(context),
                          )
                        : RefreshIndicator(
                            color: PaperclipTheme.accentGreen,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _agents.length,
                              itemBuilder: (ctx, i) => _AgentCard(
                                agent: _agents[i],
                                onAction: _handleAgentAction,
                                onRefresh: _load,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAgentAction(String action, Agent agent) async {
    final state = context.read<AppState>();
    try {
      switch (action) {
        case 'pause':
          await state.api.pauseAgent(agent.id);
        case 'resume':
          await state.api.resumeAgent(agent.id);
        case 'terminate':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Terminate Agent'),
              content: Text('Are you sure you want to terminate ${agent.name}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Terminate')),
              ],
            ),
          );
          if (confirm == true) await state.api.terminateAgent(agent.id);
        case 'wake':
          final result = await state.api.wakeAgent(agent.id);
          if (mounted) {
            final status = result['status'] as String? ?? 'unknown';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(status == 'completed'
                    ? '✅ ${agent.name} completed a task!'
                    : '⏭ ${result['message'] ?? status}'),
              ),
            );
          }
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showHireDialog(BuildContext ctx) {
    final state = ctx.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) return;
    showDialog(
      context: ctx,
      builder: (_) => _HireAgentDialog(
        companyId: company.id,
        onHired: _load,
      ),
    );
  }

  void _showAutoHireDialog(BuildContext ctx) {
    final state = ctx.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) return;
    showDialog(
      context: ctx,
      builder: (_) => _AutoHireDialog(companyId: company.id, onDone: _load),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Agent agent;
  final Future<void> Function(String, Agent) onAction;
  final VoidCallback onRefresh;

  const _AgentCard({
    required this.agent,
    required this.onAction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = agent.active;
    final statusColor = isActive ? PaperclipTheme.accentGreen : PaperclipTheme.accentAmber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: isActive ? PaperclipTheme.accentGreen.withValues(alpha: 0.2) : theme.dividerColor),
        borderRadius: BorderRadius.circular(PaperclipTheme.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PaperclipTheme.accentPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PaperclipTheme.accentPurple.withValues(alpha: 0.25)),
                  ),
                  child: Text(agent.icon ?? '🤖',
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(agent.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          _RoleBadge(role: agent.role),
                        ],
                      ),
                      Text(agent.title ?? agent.role,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withAlpha(140))),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? 'Active' : 'Paused',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.bolt_rounded,
                  label: 'Wake',
                  onTap: () => onAction('wake', agent),
                  color: PaperclipTheme.accentGreen,
                ),
                const SizedBox(width: 6),
                if (isActive)
                  _ActionBtn(
                    icon: Icons.pause_rounded,
                    label: 'Pause',
                    onTap: () => onAction('pause', agent),
                    color: PaperclipTheme.accentAmber,
                  )
                else
                  _ActionBtn(
                    icon: Icons.play_arrow_rounded,
                    label: 'Resume',
                    onTap: () => onAction('resume', agent),
                    color: PaperclipTheme.accentGreen,
                  ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.stop_circle_rounded,
                  label: 'Terminate',
                  onTap: () => onAction('terminate', agent),
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColors = {
      'ceo': const Color(0xFF9C27B0),
      'cto': const Color(0xFF2196F3),
      'manager': const Color(0xFF4CAF50),
      'engineer': const Color(0xFFFF9800),
      'pm': const Color(0xFF009688),
      'researcher': const Color(0xFF673AB7),
      'marketing': const Color(0xFFE91E63),
    };
    final color = roleColors[role.toLowerCase()] ?? const Color(0xFF6B7FD7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
            color: color, fontWeight: FontWeight.w700, fontSize: 9),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = danger ? PaperclipTheme.accentRed : (color ?? PaperclipTheme.accentCyan);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          border: Border.all(color: c.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EmptyAgents extends StatelessWidget {
  final VoidCallback onHire;
  final VoidCallback onAutoHire;

  const _EmptyAgents({required this.onHire, required this.onAutoHire});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: PaperclipTheme.accentPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PaperclipTheme.accentPurple.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 32, color: PaperclipTheme.accentPurple),
          ),
          const SizedBox(height: 16),
          Text('No Agents Yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Hire your first agent to start delegating tasks.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 22),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onAutoHire,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                label: const Text('Auto-Hire Team'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onHire,
                icon: const Icon(Icons.person_add_rounded, size: 14),
                label: const Text('Hire Agent'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Hire Agent Dialog ──────────────────────────────────────────────────────

class _HireAgentDialog extends StatefulWidget {
  final String companyId;
  final VoidCallback onHired;

  const _HireAgentDialog({required this.companyId, required this.onHired});

  @override
  State<_HireAgentDialog> createState() => _HireAgentDialogState();
}

class _HireAgentDialogState extends State<_HireAgentDialog> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _instCtrl = TextEditingController();
  String _role = 'employee';
  List<dynamic> _presets = [];
  bool _loading = false;

  static const _roles = [
    'ceo', 'cto', 'manager', 'engineer',
    'pm', 'researcher', 'marketing', 'employee', 'contractor',
  ];

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final state = context.read<AppState>();
      final presets = await state.api.getRolePresets(widget.companyId);
      if (mounted) {
        setState(() => _presets = presets);
        // Auto-fill from first preset
        _applyPreset(_role);
      }
    } catch (_) {}
  }

  void _applyPreset(String role) {
    final preset = _presets.cast<Map<String, dynamic>>()
        .where((p) => p['role'] == role)
        .firstOrNull;
    if (preset == null) return;
    _nameCtrl.text = preset['name'] as String? ?? '';
    _titleCtrl.text = preset['title'] as String? ?? '';
    if (_instCtrl.text.isEmpty) {
      _instCtrl.text = preset['instructionsPreview'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add, size: 20),
                  const SizedBox(width: 8),
                  Text('Hire Agent',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role selector
                      Text('Role',
                          style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _roles.map((r) {
                          final selected = r == _role;
                          return ChoiceChip(
                            label: Text(r.toUpperCase()),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _role = r);
                              _applyPreset(r);
                            },
                            labelStyle: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Agent Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Title (e.g. Chief Executive Officer)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _instCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Instructions (System Prompt)',
                          hintText: 'What should this agent do and how?',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _hire,
                    child: _loading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Hire'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _hire() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      await state.api.hireAgent(widget.companyId, {
        'name': _nameCtrl.text.trim(),
        'role': _role,
        'title': _titleCtrl.text.trim(),
        'instructions': _instCtrl.text.trim(),
      });
      widget.onHired();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _AutoHireDialog extends StatefulWidget {
  final String companyId;
  final VoidCallback onDone;

  const _AutoHireDialog({required this.companyId, required this.onDone});

  @override
  State<_AutoHireDialog> createState() => _AutoHireDialogState();
}

class _AutoHireDialogState extends State<_AutoHireDialog> {
  bool _loading = false;
  Map<String, dynamic>? _result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_fix_high, size: 20),
                  const SizedBox(width: 8),
                  Text('Auto-Hire Starter Team',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (_result == null) ...[
                Text(
                  'This will automatically hire a starter team for your company:\n'
                  '• 👔 CEO — Strategic leadership\n'
                  '• ⚙️ CTO — Technical direction\n'
                  '• 💻 Engineer — Implementation\n'
                  '• 📋 PM — Product management\n\n'
                  'Agents already hired will be skipped.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading ? null : _autoHire,
                      child: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Hire Team'),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 32),
                const SizedBox(height: 8),
                Text('Team hired successfully!',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: const Color(0xFF4CAF50))),
                const SizedBox(height: 4),
                Text(
                    '${(_result!['count'] as int?) ?? 0} agents joined the company.',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _autoHire() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      final result = await state.api.autoHireTeam(widget.companyId);
      widget.onDone();
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
