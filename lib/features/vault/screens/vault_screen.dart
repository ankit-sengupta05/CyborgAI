import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../github/screens/github_screen.dart';
import '../widgets/vault_sidebar.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class VaultNote {
  final String id, title, path, folder, content, summary, created, modified, type;
  final List<String> tags, links;
  final int wordCount;
  const VaultNote({required this.id, required this.title, required this.path,
      required this.folder, required this.content, this.summary = '',
      this.created = '', this.modified = '', this.type = 'note',
      this.tags = const [], this.links = const [], this.wordCount = 0});
  factory VaultNote.fromJson(Map j) => VaultNote(
    id: j['id'] ?? '', title: j['title'] ?? '', path: j['path'] ?? '',
    folder: j['folder'] ?? '', content: j['content'] ?? '',
    summary: j['summary'] ?? '', created: j['created'] ?? '',
    modified: j['modified'] ?? '', type: j['type'] ?? 'note',
    tags: List<String>.from(j['tags'] as List? ?? []),
    links: List<String>.from(j['links'] as List? ?? []),
    wordCount: j['word_count'] ?? 0);
}

// ── State ─────────────────────────────────────────────────────────────────────
class VaultState {
  final List<VaultNote> notes;
  final VaultNote? activeNote;
  final bool loading, saving, editing;
  final String search, activeFolder;
  final List<Map<String, dynamic>> folders;
  final String editContent, editTitle;
  final List<String> editTags;

  const VaultState({this.notes = const [], this.activeNote, this.loading = false,
      this.saving = false, this.editing = false, this.search = '', this.activeFolder = 'all',
      this.folders = const [], this.editContent = '', this.editTitle = '', this.editTags = const []});

  VaultState copyWith({List<VaultNote>? notes, VaultNote? activeNote, bool? loading,
      bool? saving, bool? editing, String? search, String? activeFolder,
      List<Map<String, dynamic>>? folders, String? editContent, String? editTitle,
      List<String>? editTags}) =>
    VaultState(notes: notes ?? this.notes, activeNote: activeNote ?? this.activeNote,
      loading: loading ?? this.loading, saving: saving ?? this.saving,
      editing: editing ?? this.editing, search: search ?? this.search,
      activeFolder: activeFolder ?? this.activeFolder, folders: folders ?? this.folders,
      editContent: editContent ?? this.editContent, editTitle: editTitle ?? this.editTitle,
      editTags: editTags ?? this.editTags);
}

class VaultNotifier extends StateNotifier<VaultState> {
  VaultNotifier() : super(const VaultState()) { _init(); }
  final _dio = apiDio;

  Future<void> _init() async {
    state = state.copyWith(loading: true);
    await Future.wait([loadNotes(), loadFolders()]);
    state = state.copyWith(loading: false);
  }

  Future<void> loadNotes({String? folder}) async {
    try {
      final params = <String, dynamic>{};
      if (folder != null && folder != 'all') params['folder'] = folder;
      final r = await _dio.get(ApiConstants.vaultNotes, queryParameters: params);
      final notes = (r.data['notes'] as List).map((n) => VaultNote.fromJson(n as Map)).toList();
      state = state.copyWith(notes: notes);
    } catch (_) {}
  }

  Future<void> loadFolders() async {
    try {
      final r = await _dio.get(ApiConstants.vaultFolders);
      state = state.copyWith(folders: List<Map<String, dynamic>>.from(r.data['folders'] as List? ?? []));
    } catch (_) {}
  }

  Future<void> search(String query) async {
    state = state.copyWith(search: query);
    if (query.isEmpty) { await loadNotes(); return; }
    try {
      final r = await _dio.get(ApiConstants.vaultSearch, queryParameters: {'q': query});
      final notes = (r.data['results'] as List).map((n) => VaultNote.fromJson(n as Map)).toList();
      state = state.copyWith(notes: notes);
    } catch (_) {}
  }

  void selectNote(VaultNote note) {
    state = state.copyWith(activeNote: note, editing: false,
        editContent: note.content, editTitle: note.title, editTags: note.tags);
  }

  void startEditing() => state = state.copyWith(editing: true,
      editContent: state.activeNote?.content ?? '',
      editTitle: state.activeNote?.title ?? '');

  void updateEditContent(String v) => state = state.copyWith(editContent: v);
  void updateEditTitle(String v)   => state = state.copyWith(editTitle: v);

  Future<void> saveNote() async {
    final note = state.activeNote;
    if (note == null) return;
    state = state.copyWith(saving: true);
    try {
      final r = await _dio.patch('${ApiConstants.vaultNotes}/${note.id}', data: {
        'title': state.editTitle, 'content': state.editContent,
      });
      final updated = VaultNote.fromJson(r.data as Map);
      state = state.copyWith(saving: false, editing: false, activeNote: updated,
          notes: state.notes.map((n) => n.id == updated.id ? updated : n).toList());
    } catch (_) { state = state.copyWith(saving: false); }
  }

  Future<void> createNote({String title = 'Untitled', String folder = 'inbox'}) async {
    try {
      final r = await _dio.post(ApiConstants.vaultNotes, data: {'title': title, 'folder': folder});
      final note = VaultNote.fromJson(r.data as Map);
      state = state.copyWith(notes: [note, ...state.notes]);
      selectNote(note);
      startEditing();
    } catch (_) {}
  }

  Future<void> deleteNote(String id) async {
    try {
      await _dio.delete('${ApiConstants.vaultNotes}/$id');
      state = state.copyWith(
          notes: state.notes.where((n) => n.id != id).toList(),
          activeNote: state.activeNote?.id == id ? null : state.activeNote);
    } catch (_) {}
  }

  Future<void> moveNote(String id, String folder) async {
    try {
      final r = await _dio.post('${ApiConstants.vaultNotes}/$id/move', data: {'target_folder': folder});
      final updated = VaultNote.fromJson(r.data as Map);
      state = state.copyWith(notes: state.notes.map((n) => n.id == id ? updated : n).toList());
    } catch (_) {}
  }

  void setFolder(String f) {
    state = state.copyWith(activeFolder: f, activeNote: null);
    loadNotes(folder: f == 'all' ? null : f);
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((_) => VaultNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(vaultProvider);
    final n = ref.read(vaultProvider.notifier);

    return Row(children: [
      // ── Sidebar ──────────────────────────────────────────────────────────
      const VaultSidebar(showHeader: true),
      // ── Editor/Viewer ────────────────────────────────────────────────────
      Expanded(child: s.activeNote == null
          ? _VaultEmpty(onCreate: n.createNote)
          : _NoteEditor(state: s, notifier: n)),
    ]);
  }
}

// Remove _FolderList and _NoteList as they are now in VaultSidebar

// Sidebar components moved to vault_sidebar.dart

class _NoteEditor extends ConsumerStatefulWidget {
  final VaultState state; final VaultNotifier notifier;
  const _NoteEditor({required this.state, required this.notifier});
  @override ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late TextEditingController _contentCtrl, _titleCtrl;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.state.editContent);
    _titleCtrl   = TextEditingController(text: widget.state.editTitle);
  }

  @override
  void didUpdateWidget(_NoteEditor old) {
    super.didUpdateWidget(old);
    if (widget.state.activeNote?.id != old.state.activeNote?.id) {
      _contentCtrl.text = widget.state.editContent;
      _titleCtrl.text   = widget.state.editTitle;
    }
  }

  @override
  void dispose() { _contentCtrl.dispose(); _titleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.state; final n = widget.notifier;
    final note = s.activeNote!;

    return Column(children: [
      // Note toolbar
      Container(height: 48, color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: s.editing
              ? TextField(controller: _titleCtrl,
                  onChanged: n.updateEditTitle,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true))
              : Text(note.title, style: const TextStyle(color: AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w600))),
          if (note.tags.isNotEmpty) ...note.tags.take(3).map((t) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('#$t', style: const TextStyle(fontSize: 10, color: AppColors.accent))))),
          const SizedBox(width: 12),
          if (s.editing) ...[
            if (s.saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else ElevatedButton(onPressed: n.saveNote,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                child: const Text('Save', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 6),
            OutlinedButton(onPressed: () => n.startEditing(),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                child: const Text('Cancel', style: TextStyle(fontSize: 12))),
          ] else ...[
            IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: n.startEditing, tooltip: 'Edit'),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 16),
              color: AppColors.surfaceVariant,
              onSelected: (v) {
                if (v == 'delete') n.deleteNote(note.id);
                else n.moveNote(note.id, v);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 14, color: AppColors.accentRed),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.accentRed, fontSize: 12))])),
                const PopupMenuDivider(),
                const PopupMenuItem(enabled: false, child: Text('Move to folder',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                ...['inbox', 'projects', 'areas', 'resources', 'archive', 'knowledge'].map(
                    (f) => PopupMenuItem(value: f, child: Text(f,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))),
              ],
            ),
          ],
        ]),
      ),
      const Divider(height: 1),
      // Metadata bar
      if (!s.editing) Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: AppColors.surfaceVariant,
        child: Row(children: [
          const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(note.modified.length > 10 ? note.modified.substring(0, 10) : note.modified,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(width: 12),
          const Icon(Icons.text_fields, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text('${note.wordCount} words', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          if (note.links.isNotEmpty) ...[
            const SizedBox(width: 12),
            const Icon(Icons.link, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('${note.links.length} links', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ]),
      ),
      // Content area
      Expanded(child: s.editing
          ? Padding(padding: const EdgeInsets.all(16), child: TextField(
              controller: _contentCtrl,
              maxLines: null, expands: true,
              onChanged: n.updateEditContent,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.7, fontFamily: 'monospace'),
              decoration: const InputDecoration(border: InputBorder.none,
                  hintText: '# Start writing...\n\nUse [[wiki-links]] to connect notes.'),
            ))
          : Markdown(data: note.content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.7),
                h1: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                h2: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                h3: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                code: const TextStyle(fontFamily: 'monospace', fontSize: 13,
                    color: AppColors.accentGreen, backgroundColor: AppColors.surfaceVariant),
                codeblockDecoration: BoxDecoration(color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                blockquoteDecoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.accent, width: 3))),
                listBullet: const TextStyle(color: AppColors.accent),
              ),
            )),
    ]);
  }
}

class _VaultEmpty extends StatelessWidget {
  final VoidCallback onCreate;
  const _VaultEmpty({required this.onCreate});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.edit_note_outlined, size: 48, color: AppColors.accent)),
    const SizedBox(height: 20),
    const Text('Cyborg Vault', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Your Obsidian-compatible local knowledge base.\nSelect or create a note to start.',
        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    const SizedBox(height: 24),
    ElevatedButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('New Note'), onPressed: onCreate),
  ]));
}
