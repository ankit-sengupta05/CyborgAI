import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/shared_widgets.dart';

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().reloadCompanies();
    });
  }

  void _createNewCompany() {
    showDialog(
      context: context,
      builder: (context) => const _NewCompanyDialog(),
    ).then((created) {
      if (created == true && mounted) {
        context.read<AppState>().reloadCompanies();
      }
    });
  }
  
  void _editCompany(Company company) {
     showDialog(
      context: context,
      builder: (context) => _NewCompanyDialog(existingCompany: company),
    ).then((updated) {
      if (updated == true && mounted) {
        context.read<AppState>().reloadCompanies();
      }
    });
  }

  Future<void> _deleteCompany(Company company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workspace'),
        content: Text('Are you sure you want to delete ${company.name}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _loading = true);
      try {
        await context.read<AppState>().api.deleteCompany(company.id);
        if (mounted) {
          await context.read<AppState>().reloadCompanies();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final companies = state.companies;
    final selectedId = state.selectedCompany?.id;

    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.business_center_outlined, size: 16, color: theme.colorScheme.onSurface.withAlpha(120)),
              const SizedBox(width: 8),
              Text('Workspaces', style: theme.textTheme.titleMedium),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createNewCompany,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Workspace'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : companies.isEmpty
                  ? const PcEmptyState(
                      icon: Icons.business_center_outlined,
                      title: 'No Workspaces',
                      subtitle: 'Create a workspace to manage agents and projects',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: companies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final company = companies[i];
                        final isSelected = company.id == selectedId;
                        return InkWell(
                          onTap: () => state.selectCompany(company),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary.withAlpha(20) : theme.colorScheme.surface,
                              border: Border.all(
                                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company.name,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      if (company.description?.isNotEmpty == true) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          company.description!,
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  PcBadge(label: 'Active', color: theme.colorScheme.primary),
                                  const SizedBox(width: 16),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit Workspace',
                                  onPressed: () => _editCompany(company),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  tooltip: 'Delete Workspace',
                                  onPressed: () => _deleteCompany(company),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _NewCompanyDialog extends StatefulWidget {
  final Company? existingCompany;
  const _NewCompanyDialog({this.existingCompany});

  @override
  State<_NewCompanyDialog> createState() => _NewCompanyDialogState();
}

class _NewCompanyDialogState extends State<_NewCompanyDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingCompany != null) {
      _nameCtrl.text = widget.existingCompany!.name;
      _descCtrl.text = widget.existingCompany!.description ?? '';
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<AppState>().api;
      if (widget.existingCompany != null) {
        await api.updateCompany(widget.existingCompany!.id, {
          'name': name,
          'description': _descCtrl.text.trim(),
        });
      } else {
        await api.createCompany({
          'name': name,
          'description': _descCtrl.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingCompany != null ? 'Edit Workspace' : 'New Workspace'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Workspace Name', hintText: 'e.g., Cyborg AGI'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
