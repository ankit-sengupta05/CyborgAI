import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/vault_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../github/screens/github_screen.dart';

class VaultSidebar extends ConsumerWidget {
  final bool showHeader;
  final VoidCallback? onClose;

  const VaultSidebar({
    super.key,
    this.showHeader = true,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(vaultProvider);
    final n = ref.read(vaultProvider.notifier);

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_outlined,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  const Text('Vault Explorer',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const Spacer(),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                ],
              ),
            ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              onChanged: n.search,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Search notes...',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 14),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
          // Folders
          _SharedFolderList(state: s, notifier: n),
          const Divider(height: 1),
          // Notes
          Expanded(child: _SharedNoteList(state: s, notifier: n)),
        ],
      ),
    );
  }
}

class _SharedFolderList extends StatelessWidget {
  final VaultState state;
  final VaultNotifier notifier;
  const _SharedFolderList({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final all = [
      {'key': 'all', 'name': 'All Notes'},
      ...state.folders
    ];
    return SizedBox(
      height: 180,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: all.map((f) {
          final active = state.activeFolder == f['key'];
          final icons = {
            'all': Icons.notes_outlined,
            'projects': Icons.rocket_launch_outlined,
            'areas': Icons.layers_outlined,
            'resources': Icons.library_books_outlined,
            'archive': Icons.archive_outlined,
            'inbox': Icons.inbox_outlined,
            'daily': Icons.today_outlined,
            'knowledge': Icons.psychology_outlined,
            'code': Icons.code_outlined,
            'agents': Icons.smart_toy_outlined,
            'atlas': Icons.auto_awesome_mosaic_outlined,
            'calendar': Icons.calendar_month_outlined,
            'efforts': Icons.assignment_outlined,
          };
          final icon = icons[f['key']] ?? Icons.folder_outlined;
          return ListTile(
            dense: true,
            selected: active,
            selectedTileColor: AppColors.accent.withOpacity(0.1),
            leading: Icon(icon,
                size: 14,
                color: active ? AppColors.accent : AppColors.textMuted),
            title: Text(f['name'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppColors.accent : AppColors.textSecondary,
                )),
            onTap: () => notifier.setFolder(f['key'] as String),
          );
        }).toList(),
      ),
    );
  }
}

class _SharedNoteList extends StatelessWidget {
  final VaultState state;
  final VaultNotifier notifier;
  const _SharedNoteList({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.notes.isEmpty)
      return const Center(
          child: Text('No notes',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: state.notes.length,
      itemBuilder: (_, i) {
        final note = state.notes[i];
        final active = state.activeNote?.id == note.id;
        return ListTile(
          dense: true,
          selected: active,
          selectedTileColor: AppColors.accent.withOpacity(0.1),
          title: Text(note.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.accent : AppColors.textPrimary,
              )),
          subtitle: Text(note.folder,
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          onTap: () => notifier.selectNote(note),
        );
      },
    );
  }
}
