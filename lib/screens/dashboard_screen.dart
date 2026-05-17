import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import '../../theme/paperclip_theme.dart';

/// Dashboard screen — shows company stats, live agents, and recent activity.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary? _dashboard;
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
    try {
      final data = await state.api.getDashboard(company.id);
      if (mounted) setState(() { _dashboard = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final company = state.selectedCompany;

    if (company == null) {
      return _NoCompanyView(onCreateCompany: () => _showCreateCompany(context));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PaperclipTheme.accentGreen))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: PaperclipTheme.accentGreen,
                  onRefresh: _load,
                  child: _DashboardContent(company: company, data: _dashboard, onRefresh: _load),
                ),
    );
  }

  void _showCreateCompany(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => const _CreateCompanyDialog());
  }
}

class _DashboardContent extends StatelessWidget {
  final Company company;
  final DashboardSummary? data;
  final VoidCallback onRefresh;

  const _DashboardContent({
    required this.company,
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openIssues  = data?.openIssues ?? 0;
    final inProgress  = data?.inProgressIssues ?? 0;
    final done        = data?.doneIssues ?? 0;
    final agentCount  = data?.agentCount ?? 0;
    final costCents   = data?.totalCostCents ?? 0.0;
    final activity    = data?.recentActivity ?? [];
    final liveAgents  = data?.liveAgents ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name,
                      style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700)),
                  if (company.description != null && company.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(company.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    ),
                ],
              ),
            ),
            _RefreshButton(onPressed: onRefresh),
          ],
        ),
        const SizedBox(height: 28),

        // ── Stat cards ──────────────────────────────────────────────────────
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 560 ? 4 : 2;
          return GridView.count(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(
                label: 'Open',
                value: '$openIssues',
                icon: Icons.circle_outlined,
                color: PaperclipTheme.accentCyan,
              ),
              _StatCard(
                label: 'In Progress',
                value: '$inProgress',
                icon: Icons.timelapse_rounded,
                color: PaperclipTheme.accentAmber,
              ),
              _StatCard(
                label: 'Completed',
                value: '$done',
                icon: Icons.check_circle_rounded,
                color: PaperclipTheme.accentGreen,
              ),
              _StatCard(
                label: 'Agents',
                value: '$agentCount',
                icon: Icons.smart_toy_rounded,
                color: PaperclipTheme.accentPurple,
              ),
            ],
          );
        }),

        const SizedBox(height: 28),

        // ── Live Agents ─────────────────────────────────────────────────────
        if (liveAgents.isNotEmpty) ...[
          _SectionTitle(title: 'Active Agents', count: liveAgents.length),
          const SizedBox(height: 10),
          ...liveAgents.map((a) => _AgentRow(agent: a)),
          const SizedBox(height: 28),
        ],

        // ── Recent Activity ─────────────────────────────────────────────────
        _SectionTitle(title: 'Recent Activity', count: activity.length),
        const SizedBox(height: 10),
        if (activity.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(PaperclipTheme.radius),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Text('No activity yet.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(PaperclipTheme.radius),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: activity.asMap().entries.map((entry) {
                final isLast = entry.key == activity.length - 1;
                return Column(children: [
                  _ActivityRow(item: entry.value),
                  if (!isLast) Divider(height: 1, color: theme.dividerColor),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title,
            style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: PaperclipTheme.accentGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(fontSize: 11, color: PaperclipTheme.accentGreen, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Refresh Button ─────────────────────────────────────────────────────────────
class _RefreshButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _RefreshButton({required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered
                ? theme.colorScheme.onSurface.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
            border: Border.all(color: _hovered ? theme.dividerColor : Colors.transparent),
          ),
          child: Icon(Icons.refresh_rounded, size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.color.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(PaperclipTheme.radius),
          border: Border.all(
            color: _hovered ? widget.color.withValues(alpha: 0.35) : theme.dividerColor,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.08), blurRadius: 12)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, color: widget.color, size: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.value,
                    style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.color)),
                Text(widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Agent Row ─────────────────────────────────────────────────────────────────
class _AgentRow extends StatelessWidget {
  final Agent agent;
  const _AgentRow({required this.agent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(PaperclipTheme.radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PaperclipTheme.accentPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(agent.icon ?? '🤖', style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agent.name,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                Text(agent.title ?? agent.role,
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PaperclipTheme.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PaperclipTheme.accentGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PaperclipTheme.accentGreen,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Active',
                    style: TextStyle(
                        fontSize: 11, color: PaperclipTheme.accentGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity Row ──────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: PaperclipTheme.accentCyan.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.summary ?? item.type,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
            ),
          ),
          Text(
            _timeAgo(item.createdAt),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── No Company View ────────────────────────────────────────────────────────────
class _NoCompanyView extends StatelessWidget {
  final VoidCallback onCreateCompany;
  const _NoCompanyView({required this.onCreateCompany});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PaperclipTheme.accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PaperclipTheme.accentGreen.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.business_center_rounded,
                size: 36, color: PaperclipTheme.accentGreen),
          ),
          const SizedBox(height: 20),
          Text('No Company Yet',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Create your first AI company to get started.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onCreateCompany,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create Company'),
          ),
        ],
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: PaperclipTheme.accentRed),
          const SizedBox(height: 14),
          Text('Failed to load', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Create Company Dialog ───────────────────────────────────────────────────

class _CreateCompanyDialog extends StatefulWidget {
  const _CreateCompanyDialog();

  @override
  State<_CreateCompanyDialog> createState() => _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends State<_CreateCompanyDialog> {
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _missionCtrl = TextEditingController();
  bool _loading  = false;
  bool _autoHire = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _missionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PaperclipTheme.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: PaperclipTheme.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.add_business_rounded, size: 18, color: PaperclipTheme.accentGreen),
                    ),
                    const SizedBox(width: 12),
                    Text('Create Company', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    hintText: 'e.g. Cyborg Ventures',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What does this company do?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _missionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mission Statement',
                    hintText: 'The company\'s mission...',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: PaperclipTheme.accentGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
                    border: Border.all(color: PaperclipTheme.accentGreen.withValues(alpha: 0.2)),
                  ),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text('Auto-hire starter team (CEO, CTO, Engineer, PM)',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85))),
                    value: _autoHire,
                    activeColor: PaperclipTheme.accentGreen,
                    onChanged: (v) => setState(() => _autoHire = v ?? true),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Company'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      final company = await state.api.createCompany({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'mission': _missionCtrl.text.trim(),
      });
      final companyId = company['id'] as String;
      if (_autoHire) await state.api.autoHireTeam(companyId);
      await state.connect();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
