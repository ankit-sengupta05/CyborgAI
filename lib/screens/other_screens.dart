import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/shared_widgets.dart';


// ── Approvals Screen ───────────────────────────────────────────────────────
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  List<Approval> _approvals = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'pending';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await state.api.getApprovals(company.id);
      if (mounted) setState(() { _approvals = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _act(String id, bool approve) async {
    final state = context.read<AppState>();
    setState(() => _loading = true);
    try {
      if (approve) {
        await state.api.approveApproval(id);
      } else {
        await state.api.rejectApproval(id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    if (state.selectedCompany == null) {
      return Column(children: [
        const _PageHeader(title: 'Approvals', icon: Icons.shield_outlined),
        const Expanded(child: Center(child: Text('Select a company first.'))),
      ]);
    }

    final filtered = _approvals.where((a) {
      if (_statusFilter == 'all') return true;
      return a.status == 'pending' || a.status == 'revision_requested';
    }).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final pendingCount = _approvals.where((a) => a.status == 'pending' || a.status == 'revision_requested').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(title: 'Approvals', icon: Icons.shield_outlined),
        
        // Tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
          child: Row(
            children: [
              _buildTab(theme, 'Pending', _statusFilter == 'pending', () => setState(() => _statusFilter = 'pending'), count: pendingCount),
              const SizedBox(width: 16),
              _buildTab(theme, 'All', _statusFilter == 'all', () => setState(() => _statusFilter = 'all')),
            ],
          ),
        ),

        Expanded(
          child: _loading && _approvals.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? PcEmptyState(icon: Icons.error_outline, title: _error!)
                  : filtered.isEmpty
                      ? PcEmptyState(
                          icon: Icons.shield_outlined,
                          title: _statusFilter == 'pending' ? 'No pending approvals.' : 'No approvals yet.',
                          subtitle: 'All caught up!')
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final a = filtered[i];
                            return _buildApprovalCard(theme, a);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildTab(ThemeData theme, String title, bool active, VoidCallback onTap, {int? count}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: active ? Border(bottom: BorderSide(color: theme.colorScheme.onSurface, width: 2)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: active ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(160),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCard(ThemeData theme, Approval a) {
    final isPending = a.status == 'pending' || a.status == 'revision_requested';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPending ? Icons.pending_outlined : Icons.check_circle_outline,
                size: 20,
                color: isPending ? Colors.amber : Colors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.description ?? a.type, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Requested on ${a.createdAt.toLocal().toString().split('.')[0]}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                    ),
                  ],
                ),
              ),
              PcBadge(label: a.status, color: isPending ? Colors.amber : (a.status == 'approved' ? Colors.green : Colors.red)),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _act(a.id, false),
                  child: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _act(a.id, true),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Goals Screen ───────────────────────────────────────────────────────────
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await state.api.getGoals(company.id);
      if (mounted) setState(() { _goals = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }
  
  void _createNewGoal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Goal Title'), autofocus: true),
            const SizedBox(height: 16),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              final state = context.read<AppState>();
              final companyId = state.selectedCompany?.id;
              if (companyId == null) return;
              try {
                await state.api.createGoal(companyId, {
                  'title': titleCtrl.text,
                  'description': descCtrl.text,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _load();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create goal: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    if (state.selectedCompany == null) {
      return Column(children: [
        const _PageHeader(title: 'Goals', icon: Icons.center_focus_strong_outlined),
        const Expanded(child: Center(child: Text('Select a company first.'))),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Goals', 
          icon: Icons.center_focus_strong_outlined,
          actions: [
            ElevatedButton.icon(
              onPressed: _createNewGoal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Goal'),
            ),
          ],
        ),
        Expanded(
          child: _loading && _goals.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? PcEmptyState(icon: Icons.error_outline, title: _error!)
                  : _goals.isEmpty
                      ? PcEmptyState(
                          icon: Icons.center_focus_strong_outlined,
                          title: 'No goals set',
                          subtitle: 'Define goals to align your agents',
                          actionLabel: 'New Goal',
                          onAction: _createNewGoal,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _goals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final g = _goals[i];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border.all(color: theme.dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.center_focus_strong_outlined, size: 20, color: theme.colorScheme.primary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(g.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                        if (g.description != null && g.description!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(g.description!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PcBadge(label: g.status, color: g.status == 'active' ? Colors.green : Colors.grey),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ── Projects Screen ────────────────────────────────────────────────────────
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await state.api.getProjects(company.id);
      if (mounted) setState(() { _projects = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createNewProject() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Create New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                hintText: 'e.g. Qwen2.5 Integration',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this project about?',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final state = context.read<AppState>();
              final companyId = state.selectedCompany?.id;
              if (companyId == null) return;
              try {
                await state.api.createProject(companyId, {
                  'name': nameCtrl.text,
                  'description': descCtrl.text,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create project: $e')),
                  );
                }
              }
            },
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    if (state.selectedCompany == null) {
      return Column(children: [
        const _PageHeader(title: 'Projects', icon: Icons.folder_outlined),
        const Expanded(child: Center(child: Text('Select a company first.'))),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Projects',
          icon: Icons.folder_outlined,
          actions: [
            ElevatedButton.icon(
              onPressed: _createNewProject,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Project'),
            ),
          ],
        ),
        Expanded(
          child: _loading && _projects.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _projects.isEmpty
                  ? PcEmptyState(
                      icon: Icons.folder_outlined,
                      title: 'No projects found',
                      subtitle: 'Start by creating a project to group related tasks.',
                      actionLabel: 'New Project',
                      onAction: _createNewProject,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final p = _projects[i];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.folder_outlined,
                                    size: 20, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold)),
                                    if (p.description != null &&
                                        p.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(p.description!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withAlpha(160))),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Routines Screen ────────────────────────────────────────────────────────
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Routine> _routines = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await state.api.getRoutines(company.id);
      if (mounted) setState(() { _routines = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      _PageHeader(title: 'Routines', icon: Icons.repeat),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _routines.isEmpty
                ? const PcEmptyState(
                    icon: Icons.repeat,
                    title: 'No routines scheduled',
                    subtitle: 'Routines run agents on a schedule automatically')
                : ListView.separated(
                    itemCount: _routines.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 0, color: theme.dividerColor),
                    itemBuilder: (_, i) {
                      final r = _routines[i];
                      return ListTile(
                        leading: Icon(Icons.repeat,
                            size: 16,
                            color: r.enabled
                                ? null
                                : theme.colorScheme.onSurface.withAlpha(60)),
                        title: Text(r.name, style: theme.textTheme.bodyMedium),
                        subtitle: r.schedule != null
                            ? Text(r.schedule!, style: theme.textTheme.bodySmall)
                            : null,
                        trailing: PcBadge(
                            label: r.enabled ? 'enabled' : 'disabled'),
                      );
                    }),
      ),
    ]);
  }
}

// ── Costs Screen ───────────────────────────────────────────────────────────
class CostsScreen extends StatefulWidget {
  const CostsScreen({super.key});

  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  Map<String, dynamic>? _costs;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await state.api.getCosts(company.id);
      if (mounted) setState(() { _costs = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCents(double cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }

  Widget _buildMetricTile(ThemeData theme, String label, String value, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: theme.colorScheme.onSurface.withAlpha(150)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return Column(children: [
        const _PageHeader(title: 'Costs', icon: Icons.attach_money),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ]);
    }

    if (_costs == null) {
      return Column(children: [
        const _PageHeader(title: 'Costs', icon: Icons.attach_money),
        const Expanded(
          child: PcEmptyState(
            icon: Icons.attach_money,
            title: 'No cost data',
            subtitle: 'Cost tracking data will appear here',
          ),
        ),
      ]);
    }

    final totalTokensIn = _costs!['totalTokensIn'] as int? ?? 0;
    final totalTokensOut = _costs!['totalTokensOut'] as int? ?? 0;
    final totalTokens = totalTokensIn + totalTokensOut;
    final totalCostCents = (_costs!['totalCostCents'] as num?)?.toDouble() ?? 0.0;
    final eventCount = _costs!['eventCount'] as int? ?? 0;
    final perAgent = _costs!['perAgent'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(title: 'Costs', icon: Icons.attach_money),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Costs',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inference spend, platform fees, credits, and live quota windows.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Metric Tiles ────────────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isWide ? 1.5 : 1.2,
                      children: [
                        _buildMetricTile(
                          theme,
                          'Inference spend',
                          _formatCents(totalCostCents),
                          '${_formatTokens(totalTokens)} tokens across request-scoped events',
                          Icons.attach_money,
                        ),
                        _buildMetricTile(
                          theme,
                          'Budget',
                          'Open',
                          'No monthly cap configured',
                          Icons.account_balance_wallet_outlined,
                        ),
                        _buildMetricTile(
                          theme,
                          'Finance net',
                          _formatCents(0.0),
                          '${_formatCents(0.0)} debits · ${_formatCents(0.0)} credits',
                          Icons.receipt_long_outlined,
                        ),
                        _buildMetricTile(
                          theme,
                          'Finance events',
                          eventCount.toString(),
                          '${_formatCents(0.0)} estimated in range',
                          Icons.show_chart,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                // ── Tabs Header (Visual only for now) ───────────────────────────
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      _buildTab(theme, 'Overview', true),
                      _buildTab(theme, 'Budgets', false),
                      _buildTab(theme, 'Providers', false),
                      _buildTab(theme, 'Billers', false),
                      _buildTab(theme, 'Finance', false),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Overview Content ────────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    final children = [
                      Expanded(
                        flex: isWide ? 3 : 1,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('By agent', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('What each agent consumed in the selected period.', 
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))),
                              const SizedBox(height: 16),
                              if (perAgent.isEmpty)
                                const Text('No cost events yet.', style: TextStyle(color: Colors.grey))
                              else
                                ...perAgent.map((agentData) {
                                  final totalTokens = agentData['totalTokens'] as int? ?? 0;
                                  final runCount = agentData['runCount'] as int? ?? 0;
                                  final costCents = (agentData['estimatedCostCents'] as num?)?.toDouble() ?? 0.0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: theme.dividerColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Center(
                                            child: Text(
                                              (agentData['agentId'] as String? ?? '?')[0].toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            agentData['agentId'] as String? ?? 'Unknown',
                                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(_formatCents(costCents), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                            Text(
                                              '${_formatTokens(totalTokens)} tokens · $runCount runs',
                                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
                      Expanded(
                        flex: isWide ? 2 : 1,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inference ledger', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Request-scoped inference spend for the selected period.', 
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatCents(totalCostCents),
                                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Unlimited budget', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: theme.dividerColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('USAGE', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: theme.colorScheme.onSurface.withAlpha(150))),
                                        const SizedBox(height: 4),
                                        Text(_formatTokens(totalTokens), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ];
                    
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(ThemeData theme, String title, bool active) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      decoration: BoxDecoration(
        border: active ? Border(bottom: BorderSide(color: theme.colorScheme.onSurface, width: 2)) : null,
      ),
      child: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: active ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(160),
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Activity / Inbox Screen ─────────────────────────────────────────────────
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<ActivityItem> _activity = [];
  List<Approval> _approvals = [];
  bool _loading = true;
  String _tab = 'mine'; // mine | all | approvals

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        state.api.getActivity(company.id, limit: 100),
        state.api.getApprovals(company.id),
      ]);
      if (mounted) {
        setState(() {
          _activity = results[0] as List<ActivityItem>;
          _approvals = results[1] as List<Approval>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _actOnApproval(String id, bool approve) async {
    final state = context.read<AppState>();
    try {
      if (approve) {
        await state.api.approveApproval(id);
      } else {
        await state.api.rejectApproval(id);
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingApprovals = _approvals.where((a) => a.status == 'pending' || a.status == 'revision_requested').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(title: 'Inbox', icon: Icons.inbox_outlined),

        // ── Tab bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
          child: Row(
            children: [
              _buildTab(theme, 'Mine', 'mine'),
              const SizedBox(width: 20),
              _buildTab(theme, 'All', 'all'),
              const SizedBox(width: 20),
              _buildTabWithCount(theme, 'Approvals', 'approvals', pendingApprovals),
            ],
          ),
        ),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tab == 'approvals'
                  ? _buildApprovalsTab(theme)
                  : _buildActivityTab(theme),
        ),
      ],
    );
  }

  Widget _buildTab(ThemeData theme, String label, String value) {
    final active = _tab == value;
    return GestureDetector(
      onTap: () => setState(() => _tab = value),
      child: Container(
        padding: const EdgeInsets.only(bottom: 12, top: 12),
        decoration: BoxDecoration(
          border: active ? Border(bottom: BorderSide(color: theme.colorScheme.onSurface, width: 2)) : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: active ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(150),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabWithCount(ThemeData theme, String label, String value, int count) {
    final active = _tab == value;
    return GestureDetector(
      onTap: () => setState(() => _tab = value),
      child: Container(
        padding: const EdgeInsets.only(bottom: 12, top: 12),
        decoration: BoxDecoration(
          border: active ? Border(bottom: BorderSide(color: theme.colorScheme.onSurface, width: 2)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: active ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withAlpha(150),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalsTab(ThemeData theme) {
    final pending = _approvals
        .where((a) => a.status == 'pending' || a.status == 'revision_requested')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (pending.isEmpty) {
      return const PcEmptyState(
        icon: Icons.shield_outlined,
        title: 'No pending approvals',
        subtitle: 'All caught up! Agents are running autonomously.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final a = pending[i];
        return _ApprovalFeedCard(
          approval: a,
          onApprove: () => _actOnApproval(a.id, true),
          onReject: () => _actOnApproval(a.id, false),
        );
      },
    );
  }

  Widget _buildActivityTab(ThemeData theme) {
    // Combined feed: recent issues + activity events
    final items = <_InboxFeedItem>[];

    // Add pending approvals at the top
    for (final a in _approvals.where((a) => a.status == 'pending' || a.status == 'revision_requested')) {
      items.add(_InboxFeedItem.approval(a));
    }

    // Add activity items
    if (_tab == 'mine') {
      // "Mine" = last 20 activity items
      for (final act in _activity.take(20)) {
        items.add(_InboxFeedItem.activity(act));
      }
    } else {
      // "All" = all activity
      for (final act in _activity) {
        items.add(_InboxFeedItem.activity(act));
      }
    }

    if (items.isEmpty) {
      return const PcEmptyState(
        icon: Icons.inbox_outlined,
        title: 'Nothing here yet',
        subtitle: 'Activity and notifications will appear as agents work.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(0),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 0, color: theme.dividerColor),
        itemBuilder: (_, i) {
          final item = items[i];
          if (item.approval != null) {
            return _ApprovalFeedCard(
              approval: item.approval!,
              compact: true,
              onApprove: () => _actOnApproval(item.approval!.id, true),
              onReject: () => _actOnApproval(item.approval!.id, false),
            );
          }
          return _ActivityFeedRow(item: item.activity!, theme: theme);
        },
      ),
    );
  }
}

class _InboxFeedItem {
  final Approval? approval;
  final ActivityItem? activity;
  _InboxFeedItem.approval(this.approval) : activity = null;
  _InboxFeedItem.activity(this.activity) : approval = null;
}

class _ActivityFeedRow extends StatelessWidget {
  final ActivityItem item;
  final ThemeData theme;
  const _ActivityFeedRow({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    final timeStr = _timeAgo(item.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _iconForType(item.type),
              size: 16,
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.summary ?? item.type,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(130),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'issue_created' => Icons.add_circle_outline,
      'issue_updated' => Icons.edit_outlined,
      'issue_done' => Icons.check_circle_outline,
      'agent_run' => Icons.play_circle_outline,
      'agent_failed' => Icons.error_outline,
      'approval_requested' => Icons.shield_outlined,
      'approval_resolved' => Icons.shield_outlined,
      _ => Icons.circle_outlined,
    };
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _ApprovalFeedCard extends StatelessWidget {
  final Approval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool compact;

  const _ApprovalFeedCard({
    required this.approval,
    required this.onApprove,
    required this.onReject,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = approval.status == 'pending' || approval.status == 'revision_requested';

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.shield_outlined, size: 16, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(approval.description ?? approval.type,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Pending approval · ${_timeAgo(approval.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isPending) ...[
              TextButton(
                onPressed: onReject,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Approve', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  approval.description ?? approval.type,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              PcBadge(label: approval.status, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Requested ${_timeAgo(approval.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  child: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onApprove,
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Org Chart Screen ───────────────────────────────────────────────────────
class OrgChartScreen extends StatefulWidget {
  const OrgChartScreen({super.key});

  @override
  State<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends State<OrgChartScreen> {
  List<Agent> _agents = [];
  bool _loading = true;
  final Map<String, Offset> _nodePositions = {};

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final data = await state.api.getAgents(company.id);
      if (mounted) {
        setState(() { 
          _agents = data; 
          _loading = false; 
        });
        _initializeLayout();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _getLevel(Agent a) {
    final r = (a.title ?? a.role).toLowerCase();
    if (r.contains('ceo') || r.contains('chief executive')) return 0;
    if (r.contains('chief') || r.contains('vp') || r.contains('cto')) return 1;
    if (r.contains('manager') || r.contains('director') || r.contains('head')) return 2;
    return 3;
  }

  void _initializeLayout() {
    if (_nodePositions.isNotEmpty) return; // Only layout once

    final levels = <int, List<Agent>>{};
    for (var a in _agents) {
      final l = _getLevel(a);
      levels.putIfAbsent(l, () => []).add(a);
    }

    final nodeWidth = 240.0;
    final nodeHeight = 70.0;
    final xSpacing = 50.0;
    final ySpacing = 80.0;

    final positions = <String, Offset>{};
    int maxLevel = levels.keys.isEmpty ? 0 : levels.keys.reduce((a, b) => a > b ? a : b);

    for (int l = 0; l <= maxLevel; l++) {
      final agents = levels[l] ?? [];
      final totalWidth = agents.length * nodeWidth + (agents.length - 1) * xSpacing;
      double startX = -totalWidth / 2 + nodeWidth / 2;
      for (int i = 0; i < agents.length; i++) {
        positions[agents[i].id] = Offset(startX + i * (nodeWidth + xSpacing), l * (nodeHeight + ySpacing));
      }
    }

    double minX = 0;
    for (var pos in positions.values) {
      if (pos.dx < minX) minX = pos.dx;
    }

    for (var e in positions.entries) {
      _nodePositions[e.key] = Offset(e.value.dx - minX + 80, e.value.dy + 80);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return Column(children: [
        const _PageHeader(title: 'Org Chart', icon: Icons.account_tree_outlined),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ]);
    }

    if (_agents.isEmpty) {
      return Column(children: [
        const _PageHeader(title: 'Org Chart', icon: Icons.account_tree_outlined),
        const Expanded(
          child: PcEmptyState(
            icon: Icons.account_tree_outlined,
            title: 'No agents',
            subtitle: 'Hire agents to build your org chart',
          ),
        ),
      ]);
    }

    final levels = <int, List<Agent>>{};
    for (var a in _agents) {
      final l = _getLevel(a);
      levels.putIfAbsent(l, () => []).add(a);
    }

    int maxLevel = levels.keys.isEmpty ? 0 : levels.keys.reduce((a, b) => a > b ? a : b);

    final parentLinks = <String, String>{};
    for (int l = 1; l <= maxLevel; l++) {
      final agents = levels[l] ?? [];
      int parentLevel = l - 1;
      while (parentLevel >= 0 && (levels[parentLevel] == null || levels[parentLevel]!.isEmpty)) {
        parentLevel--;
      }
      final parents = levels[parentLevel] ?? [];
      if (parents.isNotEmpty) {
        for (int i = 0; i < agents.length; i++) {
          final parent = parents[i % parents.length];
          parentLinks[agents[i].id] = parent.id;
        }
      }
    }

    final nodeWidth = 240.0;
    final nodeHeight = 70.0;

    double maxX = 0;
    double maxY = 0;
    for (var pos in _nodePositions.values) {
      if (pos.dx > maxX) maxX = pos.dx;
      if (pos.dy > maxY) maxY = pos.dy;
    }

    final width = maxX + nodeWidth + 160;
    final height = maxY + nodeHeight + 160;

    return Column(children: [
      const _PageHeader(title: 'Org Chart', icon: Icons.account_tree_outlined),
      Expanded(
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(1000),
            minScale: 0.1,
            maxScale: 2.0,
            child: SizedBox(
              width: width < MediaQuery.of(context).size.width ? MediaQuery.of(context).size.width : width,
              height: height < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.height : height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OrgChartPainter(
                        positions: _nodePositions,
                        links: parentLinks,
                        nodeWidth: nodeWidth,
                        nodeHeight: nodeHeight,
                        theme: theme,
                      ),
                    ),
                  ),
                  for (var a in _agents)
                    if (_nodePositions.containsKey(a.id))
                      Positioned(
                        left: _nodePositions[a.id]!.dx,
                        top: _nodePositions[a.id]!.dy,
                        width: nodeWidth,
                        height: nodeHeight,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _nodePositions[a.id] = _nodePositions[a.id]! + details.delta;
                            });
                          },
                          child: _buildNode(a, theme),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNode(Agent a, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(a.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(a.title ?? a.role, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        PcConnectionBadge(connected: a.active),
      ]),
    );
  }
}

class _OrgChartPainter extends CustomPainter {
  final Map<String, Offset> positions;
  final Map<String, String> links;
  final double nodeWidth;
  final double nodeHeight;
  final ThemeData theme;

  _OrgChartPainter({
    required this.positions,
    required this.links,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.dividerColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var childId in links.keys) {
      final parentId = links[childId]!;
      final childPos = positions[childId];
      final parentPos = positions[parentId];

      if (childPos != null && parentPos != null) {
        final start = Offset(parentPos.dx + nodeWidth / 2, parentPos.dy + nodeHeight);
        final end = Offset(childPos.dx + nodeWidth / 2, childPos.dy);

        final path = Path();
        path.moveTo(start.dx, start.dy);
        
        // Draw orthogonal lines
        final midY = (start.dy + end.dy) / 2;
        path.lineTo(start.dx, midY);
        path.lineTo(end.dx, midY);
        path.lineTo(end.dx, end.dy);

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Shared page header ─────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget>? actions;

  const _PageHeader({required this.title, required this.icon, this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurface.withAlpha(120)),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium),
        const Spacer(),
        ...?actions,
      ]),
    );
  }
}
