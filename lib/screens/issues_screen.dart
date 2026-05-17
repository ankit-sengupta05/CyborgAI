import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/paperclip_theme.dart';
import '../widgets/shared_widgets.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  List<Issue> _issues = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | open | in_progress | done

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      final status = _filter == 'all' ? null : _filter;
      final issues = await state.api.getIssues(company.id, status: status);
      if (mounted) setState(() { _issues = issues; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        backgroundColor: PaperclipTheme.accentGreen,
        foregroundColor: const Color(0xFF001A12),
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
        // ── Header bar ─────────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Text('Issues', style: theme.textTheme.titleMedium),
              const Spacer(),
              _FilterChip(label: 'All',         selected: _filter == 'all',         onTap: () { setState(() => _filter = 'all');         _load(); }),
              const SizedBox(width: 6),
              _FilterChip(label: 'Open',        selected: _filter == 'open',        onTap: () { setState(() => _filter = 'open');        _load(); }),
              const SizedBox(width: 6),
              _FilterChip(label: 'In Progress', selected: _filter == 'in_progress', onTap: () { setState(() => _filter = 'in_progress'); _load(); }),
              const SizedBox(width: 6),
              _FilterChip(label: 'Done',        selected: _filter == 'done',        onTap: () { setState(() => _filter = 'done');        _load(); }),
            ],
          ),
        ),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: PaperclipTheme.accentGreen))
              : _error != null
                  ? PcEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Failed to load',
                      subtitle: _error,
                      action: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          onPressed: _load,
                          label: const Text('Retry')),
                    )
                  : _issues.isEmpty
                      ? const PcEmptyState(
                          icon: Icons.circle_outlined,
                          title: 'No issues',
                          subtitle: 'Create an issue to get started',
                        )
                      : RefreshIndicator(
                          color: PaperclipTheme.accentGreen,
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: _issues.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 0, color: theme.dividerColor),
                            itemBuilder: (_, i) => _IssueListItem(issue: _issues[i]),
                          ),
                        ),
        ),
      ],
    ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateIssueDialog(
        companyId: context.read<AppState>().selectedCompany!.id,
        onCreated: _load,
      ),
    );
  }
}

// ── Filter chip ─────────────────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg, fg, bord;
    if (widget.selected) {
      bg   = PaperclipTheme.accentGreen.withValues(alpha: 0.12);
      fg   = PaperclipTheme.accentGreen;
      bord = PaperclipTheme.accentGreen.withValues(alpha: 0.4);
    } else if (_hovered) {
      bg   = theme.colorScheme.onSurface.withValues(alpha: 0.06);
      fg   = theme.colorScheme.onSurface.withValues(alpha: 0.8);
      bord = theme.dividerColor;
    } else {
      bg   = Colors.transparent;
      fg   = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      bord = theme.dividerColor;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bord),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                  color: fg)),
        ),
      ),
    );
  }
}

class _IssueListItem extends StatelessWidget {
  final Issue issue;

  const _IssueListItem({required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            PcStatusIcon(status: issue.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.title, style: theme.textTheme.bodyMedium),
                  if (issue.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      issue.description!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_timeAgo(issue.updatedAt), style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PaperclipTheme.radiusLg),
      ),
      builder: (_) => _IssueDetailSheet(issue: issue),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

class _IssueDetailSheet extends StatelessWidget {
  final Issue issue;

  const _IssueDetailSheet({required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                PcStatusIcon(status: issue.status, size: 16),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(issue.title,
                        style: theme.textTheme.headlineSmall)),
              ]),
              const SizedBox(height: 12),
              if (issue.description?.isNotEmpty == true)
                Text(issue.description!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              _row('Status', issue.status.name, theme),
              if (issue.assigneeId != null)
                _row('Assignee', issue.assigneeId!, theme),
              _row('Created', _fmt(issue.createdAt), theme),
              _row('Updated', _fmt(issue.updatedAt), theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
                width: 80,
                child: Text(label, style: theme.textTheme.labelMedium)),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      );

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _CreateIssueDialog extends StatefulWidget {
  final String companyId;
  final VoidCallback onCreated;

  const _CreateIssueDialog({required this.companyId, required this.onCreated});

  @override
  State<_CreateIssueDialog> createState() => _CreateIssueDialogState();
}

class _CreateIssueDialogState extends State<_CreateIssueDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Issue', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
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
                      onPressed: _loading ? null : _submit,
                      child: _loading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create'),
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
    try {
      final state = context.read<AppState>();
      await state.api.createIssue(widget.companyId, {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }
}

