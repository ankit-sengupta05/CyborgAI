import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../theme/paperclip_theme.dart';
import '../../../core/theme/app_theme.dart' show Responsive;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../github/screens/github_screen.dart';
import '../widgets/vault_sidebar.dart';
import '../repositories/vault_repository.dart';



// ── Models ────────────────────────────────────────────────────────────────────
class VaultNote {
  final String id,
      title,
      path,
      folder,
      content,
      summary,
      created,
      modified,
      type;
  final List<String> tags, links;
  final int wordCount;
  const VaultNote(
      {required this.id,
      required this.title,
      required this.path,
      required this.folder,
      required this.content,
      this.summary = '',
      this.created = '',
      this.modified = '',
      this.type = 'note',
      this.tags = const [],
      this.links = const [],
      this.wordCount = 0});
  factory VaultNote.fromJson(Map j) => VaultNote(
      id: j['id'] ?? '',
      title: j['title'] ?? '',
      path: j['path'] ?? '',
      folder: j['folder'] ?? '',
      content: j['content'] ?? '',
      summary: j['summary'] ?? '',
      created: j['created'] ?? '',
      modified: j['modified'] ?? '',
      type: j['type'] ?? 'note',
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

  const VaultState(
      {this.notes = const [],
      this.activeNote,
      this.loading = false,
      this.saving = false,
      this.editing = false,
      this.search = '',
      this.activeFolder = 'all',
      this.folders = const [],
      this.editContent = '',
      this.editTitle = '',
      this.editTags = const []});

  VaultState copyWith(
          {List<VaultNote>? notes,
          VaultNote? activeNote,
          bool? loading,
          bool? saving,
          bool? editing,
          String? search,
          String? activeFolder,
          List<Map<String, dynamic>>? folders,
          String? editContent,
          String? editTitle,
          List<String>? editTags}) =>
      VaultState(
          notes: notes ?? this.notes,
          activeNote: activeNote ?? this.activeNote,
          loading: loading ?? this.loading,
          saving: saving ?? this.saving,
          editing: editing ?? this.editing,
          search: search ?? this.search,
          activeFolder: activeFolder ?? this.activeFolder,
          folders: folders ?? this.folders,
          editContent: editContent ?? this.editContent,
          editTitle: editTitle ?? this.editTitle,
          editTags: editTags ?? this.editTags);
}

class VaultNotifier extends StateNotifier<VaultState> {
  final VaultRepository _repo;

  VaultNotifier() : _repo = (Platform.isWindows || kIsWeb) ? RemoteVaultRepository() : LocalVaultRepository(),
                    super(const VaultState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(loading: true);
    try {
      await Future.wait([loadNotes(), loadFolders()]);
    } catch (_) {}
    state = state.copyWith(loading: false);
  }

  Future<void> loadNotes({String? folder}) async {
    try {
      final notes = await _repo.getNotes(folder: folder);
      state = state.copyWith(notes: notes);
    } catch (_) {}
  }

  Future<void> loadFolders() async {
    try {
      final folders = await _repo.getFolders();
      state = state.copyWith(folders: folders);
    } catch (_) {}
  }

  Future<void> search(String query) async {
    state = state.copyWith(search: query);
    if (query.isEmpty) {
      await loadNotes();
      return;
    }
    try {
      final results = await _repo.search(query);
      state = state.copyWith(notes: results);
    } catch (_) {}
  }

  void selectNote(VaultNote note) {
    state = state.copyWith(
        activeNote: note,
        editing: false,
        editContent: note.content,
        editTitle: note.title,
        editTags: note.tags);
  }

  Future<void> selectNoteById(String id) async {
    // 1. Check if already loaded
    final existing = state.notes.where((n) => n.id == id).firstOrNull;
    if (existing != null) {
      selectNote(existing);
      return;
    }

    // 2. Load from API if not in list
    try {
      final note = await _repo.getNote(id);
      state = state.copyWith(notes: [note, ...state.notes]);
      selectNote(note);
    } catch (_) {
      // If failed, just go to vault
    }
  }

  void startEditing() => state = state.copyWith(
      editing: true,
      editContent: state.activeNote?.content ?? '',
      editTitle: state.activeNote?.title ?? '');

  void updateEditContent(String v) => state = state.copyWith(editContent: v);
  void updateEditTitle(String v) => state = state.copyWith(editTitle: v);

  Future<void> saveNote() async {
    final note = state.activeNote;
    if (note == null) return;
    state = state.copyWith(saving: true);
    try {
      final updated = await _repo.updateNote(note.id, 
          title: state.editTitle, 
          content: state.editContent);
      
      state = state.copyWith(
          saving: false,
          editing: false,
          activeNote: updated,
          notes: state.notes
              .map((n) => n.id == updated.id ? updated : n)
              .toList());
    } catch (_) {
      state = state.copyWith(saving: false);
    }
  }

  Future<void> createNote(
      {String title = 'Untitled', String folder = 'inbox'}) async {
    try {
      final note = await _repo.createNote(title: title, folder: folder);
      state = state.copyWith(notes: [note, ...state.notes]);
      selectNote(note);
      startEditing();
    } catch (_) {}
  }

  Future<void> deleteNote(String id) async {
    try {
      await _repo.deleteNote(id);
      state = state.copyWith(
          notes: state.notes.where((n) => n.id != id).toList(),
          activeNote: state.activeNote?.id == id ? null : state.activeNote);
    } catch (_) {}
  }

  Future<void> moveNote(String id, String folder) async {
    try {
      final updated = await _repo.moveNote(id, folder);
      state = state.copyWith(
          notes: state.notes.map((n) => n.id == id ? updated : n).toList());
    } catch (_) {}
  }

  void setFolder(String f) {
    state = state.copyWith(activeFolder: f, activeNote: null);
    loadNotes(folder: f == 'all' ? null : f);
  }
}

final vaultProvider =
    StateNotifierProvider<VaultNotifier, VaultState>((_) => VaultNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(vaultProvider);
    final n = ref.read(vaultProvider.notifier);
    final isMobile = Responsive.isMobile(context);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    final editor = s.activeNote == null
        ? _VaultEmpty(onCreate: n.createNote)
        : _NoteEditor(state: s, notifier: n);

    if (isMobile) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: PaperclipTheme.backgroundDark,
        drawer: Drawer(
          width: 280,
          backgroundColor: PaperclipTheme.sidebarDark,
          child: VaultSidebar(
            showHeader: true,
            onClose: () => scaffoldKey.currentState?.closeDrawer(),
          ),
        ),
        appBar: AppBar(
          toolbarHeight: 40,
          backgroundColor: PaperclipTheme.sidebarDark,
          leading: IconButton(
            icon: const Icon(Icons.folder_outlined, size: 18),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            s.activeNote?.title ?? 'Vault Explorer',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: n.createNote,
            ),
          ],
        ),
        body: editor,
      );
    }

    return Row(children: [
      const VaultSidebar(showHeader: true),
      Expanded(child: editor),
    ]);
  }
}

// Remove _FolderList and _NoteList as they are now in VaultSidebar

// Sidebar components moved to vault_sidebar.dart

class _NoteEditor extends ConsumerStatefulWidget {
  final VaultState state;
  final VaultNotifier notifier;
  const _NoteEditor({required this.state, required this.notifier});
  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late TextEditingController _contentCtrl, _titleCtrl;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.state.editContent);
    _titleCtrl = TextEditingController(text: widget.state.editTitle);
  }

  @override
  void didUpdateWidget(_NoteEditor old) {
    super.didUpdateWidget(old);
    if (widget.state.activeNote?.id != old.state.activeNote?.id) {
      _contentCtrl.text = widget.state.editContent;
      _titleCtrl.text = widget.state.editTitle;
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final n = widget.notifier;
    final note = s.activeNote!;

    return Column(children: [
      // Note toolbar
      Container(
        height: 48,
        color: PaperclipTheme.surfaceDark,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(
              child: s.editing
                  ? TextField(
                      controller: _titleCtrl,
                      onChanged: n.updateEditTitle,
                      style: const TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                          border: InputBorder.none, isDense: true))
                  : Text(note.title,
                      style: const TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600))),
          if (note.tags.isNotEmpty)
            ...note.tags.take(3).map((t) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: PaperclipTheme.accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('#$t',
                        style: const TextStyle(
                            fontSize: 10, color: PaperclipTheme.accentCyan))))),
          const SizedBox(width: 12),
          if (s.editing) ...[
            if (s.saving)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              ElevatedButton(
                  onPressed: n.saveNote,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8)),
                  child: const Text('Save', style: TextStyle(fontSize: 12))),
            const SizedBox(width: 6),
            OutlinedButton(
                onPressed: () => n.startEditing(),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8)),
                child: const Text('Cancel', style: TextStyle(fontSize: 12))),
          ] else ...[
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: n.startEditing,
                tooltip: 'Edit'),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, size: 16),
              color: PaperclipTheme.surfaceElevatedDark,
              onSelected: (v) {
                if (v == 'delete')
                  n.deleteNote(note.id);
                else
                  n.moveNote(note.id, v);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 14, color: PaperclipTheme.accentRed),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(
                              color: PaperclipTheme.accentRed, fontSize: 12))
                    ])),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    enabled: false,
                    child: Text('Move to folder',
                        style: TextStyle(
                            color: PaperclipTheme.mutedFgDark, fontSize: 11))),
                ...[
                  'inbox',
                  'projects',
                  'areas',
                  'resources',
                  'archive',
                  'knowledge'
                ].map((f) => PopupMenuItem(
                    value: f,
                    child: Text(f,
                        style: const TextStyle(
                            fontSize: 12, color: PaperclipTheme.mutedDark)))),
              ],
            ),
          ],
        ]),
      ),
      const Divider(height: 1),
      // Metadata bar
      if (!s.editing)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: PaperclipTheme.surfaceElevatedDark,
          child: Row(children: [
            const Icon(Icons.access_time, size: 12, color: PaperclipTheme.mutedFgDark),
            const SizedBox(width: 4),
            Text(
                note.modified.length > 10
                    ? note.modified.substring(0, 10)
                    : note.modified,
                style:
                    const TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 11)),
            const SizedBox(width: 12),
            const Icon(Icons.text_fields, size: 12, color: PaperclipTheme.mutedFgDark),
            const SizedBox(width: 4),
            Text('${note.wordCount} words',
                style:
                    const TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 11)),
            if (note.links.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(Icons.link, size: 12, color: PaperclipTheme.mutedFgDark),
              const SizedBox(width: 4),
              Text('${note.links.length} links',
                  style: const TextStyle(
                      color: PaperclipTheme.mutedFgDark, fontSize: 11)),
            ],
          ]),
        ),
      // Content area
      Expanded(
          child: s.editing
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    expands: true,
                    onChanged: n.updateEditContent,
                    style: const TextStyle(
                        color: PaperclipTheme.foregroundDark,
                        fontSize: 14,
                        height: 1.7,
                        fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            '# Start writing...\n\nUse [[wiki-links]] to connect notes.'),
                  ))
              : Markdown(
                  data: note.content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        color: PaperclipTheme.foregroundDark,
                        fontSize: 14,
                        height: 1.7),
                    h1: const TextStyle(
                        color: PaperclipTheme.foregroundDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                    h2: const TextStyle(
                        color: PaperclipTheme.foregroundDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                    h3: const TextStyle(
                        color: PaperclipTheme.mutedDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    code: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: PaperclipTheme.accentGreen,
                        backgroundColor: PaperclipTheme.surfaceElevatedDark),
                    codeblockDecoration: BoxDecoration(
                        color: PaperclipTheme.surfaceElevatedDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PaperclipTheme.borderDark)),
                    blockquoteDecoration: const BoxDecoration(
                        border: Border(
                            left:
                                BorderSide(color: PaperclipTheme.accentCyan, width: 3))),
                    listBullet: const TextStyle(color: PaperclipTheme.accentCyan),
                  ),
                )),
    ]);
  }
}

class _VaultEmpty extends StatelessWidget {
  final VoidCallback onCreate;
  const _VaultEmpty({required this.onCreate});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: PaperclipTheme.accentCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.edit_note_outlined,
                size: 48, color: PaperclipTheme.accentCyan)),
        const SizedBox(height: 20),
        const Text('Cyborg Vault',
            style: TextStyle(
                color: PaperclipTheme.foregroundDark,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
            'Your Obsidian-compatible local knowledge base.\nSelect or create a note to start.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PaperclipTheme.mutedDark, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Note'),
            onPressed: onCreate),
      ]));
}
