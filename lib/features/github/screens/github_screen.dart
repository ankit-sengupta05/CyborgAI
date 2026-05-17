import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';

class GitHubRepo {
  final String name;
  final String fullName;
  final String description;
  final bool private;
  final String url;
  final int stars;
  final String language;
  final DateTime updatedAt;

  const GitHubRepo({
    required this.name,
    required this.fullName,
    required this.description,
    required this.private,
    required this.url,
    required this.stars,
    required this.language,
    required this.updatedAt,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
        name: json['name'] ?? '',
        fullName: json['full_name'] ?? '',
        description: json['description'] ?? '',
        private: json['private'] ?? false,
        url: json['html_url'] ?? '',
        stars: json['stargazers_count'] ?? 0,
        language: json['language'] ?? 'Unknown',
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}

class GitHubFile {
  final String name;
  final String path;
  final String type;
  final int size;
  final String url;

  const GitHubFile({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.url,
  });

  factory GitHubFile.fromJson(Map<String, dynamic> json) => GitHubFile(
        name: json['name'] ?? '',
        path: json['path'] ?? '',
        type: json['type'] ?? 'file',
        size: json['size'] ?? 0,
        url: json['url'] ?? '',
      );

  bool get isDir => type == 'dir';
}

class GitHubState {
  final bool isConnected;
  final String? username;
  final String? avatarUrl;
  final List<GitHubRepo> repos;
  final String searchQuery;
  final bool isSyncing;
  final String? lastSyncedRepo;
  final String? error;
  final String? lastError;

  final GitHubRepo? selectedRepo;
  final List<GitHubFile> repoContents;
  final String currentPath;
  final bool isLoadingContents;

  // Vault
  final String? vaultRepo;
  final bool isCreatingVault;

  // File content
  final GitHubFile? selectedFile;
  final String? selectedFileContent;
  final bool isLoadingFile;

  const GitHubState({
    this.isConnected = false,
    this.username,
    this.avatarUrl,
    this.repos = const [],
    this.searchQuery = '',
    this.isSyncing = false,
    this.lastSyncedRepo,
    this.error,
    this.lastError,
    this.selectedRepo,
    this.repoContents = const [],
    this.currentPath = '',
    this.isLoadingContents = false,
    this.vaultRepo,
    this.isCreatingVault = false,
    this.selectedFile,
    this.selectedFileContent,
    this.isLoadingFile = false,
  });

  List<GitHubRepo> get filteredRepos => repos
      .where((r) => r.name.toLowerCase().contains(searchQuery.toLowerCase()))
      .toList();

  GitHubState copyWith({
    bool? isConnected,
    String? username,
    String? avatarUrl,
    List<GitHubRepo>? repos,
    String? searchQuery,
    bool? isSyncing,
    String? lastSyncedRepo,
    String? error,
    String? lastError,
    GitHubRepo? selectedRepo,
    bool clearSelectedRepo = false,
    List<GitHubFile>? repoContents,
    String? currentPath,
    bool? isLoadingContents,
    String? vaultRepo,
    bool clearVaultRepo = false,
    bool? isCreatingVault,
    GitHubFile? selectedFile,
    bool clearSelectedFile = false,
    String? selectedFileContent,
    bool? isLoadingFile,
  }) =>
      GitHubState(
        isConnected: isConnected ?? this.isConnected,
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        repos: repos ?? this.repos,
        searchQuery: searchQuery ?? this.searchQuery,
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncedRepo: lastSyncedRepo ?? this.lastSyncedRepo,
        error: error,
        lastError: lastError ?? this.lastError,
        selectedRepo:
            clearSelectedRepo ? null : (selectedRepo ?? this.selectedRepo),
        repoContents: repoContents ?? this.repoContents,
        currentPath: currentPath ?? this.currentPath,
        isLoadingContents: isLoadingContents ?? this.isLoadingContents,
        vaultRepo: clearVaultRepo ? null : (vaultRepo ?? this.vaultRepo),
        isCreatingVault: isCreatingVault ?? this.isCreatingVault,
        selectedFile:
            clearSelectedFile ? null : (selectedFile ?? this.selectedFile),
        selectedFileContent: selectedFileContent ?? this.selectedFileContent,
        isLoadingFile: isLoadingFile ?? this.isLoadingFile,
      );
}

class GitHubNotifier extends StateNotifier<GitHubState> {
  GitHubNotifier() : super(const GitHubState()) {
    _checkConnection();
  }

  final _dio = apiDio;

  Future<void> _checkConnection() async {
    try {
      final resp = await _dio.get(ApiConstants.githubStatus);
      if (resp.data['connected'] == true) {
        state = state.copyWith(
          isConnected: true,
          username: resp.data['username'],
          avatarUrl: resp.data['avatar_url'],
          vaultRepo: resp.data['vault_repo'],
          lastError: resp.data['last_error'],
        );
        await loadRepos();
      }
    } catch (_) {}
  }

  Future<void> connect(String token) async {
    try {
      final resp =
          await _dio.post(ApiConstants.githubConnect, data: {'token': token});
      state = state.copyWith(
        isConnected: true,
        username: resp.data['username'],
        avatarUrl: resp.data['avatar_url'],
        vaultRepo: resp.data['vault_repo'],
        error: null,
      );
      await loadRepos();
    } catch (e) {
      String msg = e.toString();
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          msg = 'Invalid Token: The GitHub Personal Access Token you provided was rejected. Please check for typos and ensure it hasn\'t expired.';
        } else {
          msg = e.response?.data?['detail'] ?? e.message ?? 'Unknown connection error';
        }
      }
      state = state.copyWith(error: msg);
    }
  }

  Future<void> setVault(String repoFullName) async {
    try {
      await _dio
          .post(ApiConstants.githubVaultSet, data: {'repo': repoFullName});
      state = state.copyWith(vaultRepo: repoFullName);
      await loadRepos(); // Refresh and auto-select
    } catch (e) {
      state = state.copyWith(error: 'Failed to set vault: $e');
    }
  }

  Future<void> createVault(String name) async {
    state = state.copyWith(isCreatingVault: true);
    try {
      final resp =
          await _dio.post(ApiConstants.githubVaultCreate, data: {'name': name});
      state =
          state.copyWith(vaultRepo: resp.data['repo'], isCreatingVault: false);
      await loadRepos(); // Refresh and auto-select
    } catch (e) {
      state = state.copyWith(
          isCreatingVault: false, error: 'Failed to create vault: $e');
    }
  }

  Future<void> clearVault() async {
    state = state.copyWith(clearVaultRepo: true);
  }

  Future<void> loadRepos() async {
    try {
      final resp = await _dio.get(ApiConstants.githubRepos);
      final repos = (resp.data['repos'] as List)
          .map((r) => GitHubRepo.fromJson(r))
          .toList();
      state = state.copyWith(repos: repos);

      // Auto-select vault if it exists
      if (state.vaultRepo != null) {
        for (final repo in repos) {
          if (repo.fullName == state.vaultRepo) {
            selectRepo(repo);
            break;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> syncRepo(String repoName) async {
    state = state.copyWith(isSyncing: true, lastSyncedRepo: repoName);
    try {
      await _dio.post(ApiConstants.githubSync, data: {'repo': repoName});
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> selectRepo(GitHubRepo? repo) async {
    if (repo == null) {
      state = state.copyWith(
          clearSelectedRepo: true, repoContents: [], currentPath: '');
      return;
    }
    state =
        state.copyWith(selectedRepo: repo, currentPath: '', repoContents: []);
    await loadRepoContents('');
  }

  Future<void> loadRepoContents(String path) async {
    if (state.selectedRepo == null) return;
    state = state.copyWith(isLoadingContents: true, currentPath: path);
    try {
      final resp = await _dio.get(
        '${ApiConstants.githubRepos}/${state.selectedRepo!.fullName}/contents',
        queryParameters: {'path': path},
      );
      final items = (resp.data['items'] as List)
          .map((i) => GitHubFile.fromJson(i))
          .toList();
      state = state.copyWith(repoContents: items, isLoadingContents: false);
    } catch (e) {
      state = state.copyWith(
          isLoadingContents: false, error: 'Failed to load contents: $e');
    }
  }

  Future<void> selectFile(GitHubFile? file) async {
    if (file == null) {
      state =
          state.copyWith(clearSelectedFile: true, selectedFileContent: null);
      return;
    }
    state = state.copyWith(
        selectedFile: file, isLoadingFile: true, selectedFileContent: null);
    await loadRepoFile(file.path);
  }

  Future<void> loadRepoFile(String path) async {
    if (state.selectedRepo == null) return;
    try {
      final resp = await _dio.get(
        '${ApiConstants.githubRepos}/${state.selectedRepo!.fullName}/file',
        queryParameters: {'path': path},
      );
      state = state.copyWith(
        selectedFileContent: resp.data['content'],
        isLoadingFile: false,
      );
    } catch (e) {
      state = state.copyWith(
          isLoadingFile: false, error: 'Failed to load file: $e');
    }
  }

  Future<void> disconnect() async {
    state = const GitHubState();
  }
}

final githubProvider = StateNotifierProvider<GitHubNotifier, GitHubState>(
    (ref) => GitHubNotifier());

class GitHubScreen extends ConsumerStatefulWidget {
  const GitHubScreen({super.key});

  @override
  ConsumerState<GitHubScreen> createState() => _GitHubScreenState();
}

class _GitHubScreenState extends ConsumerState<GitHubScreen> {
  final _tokenController = TextEditingController();
  bool _obscureToken = true;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final github = ref.watch(githubProvider);

    return Column(
      children: [
        // Header
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.surface,
          child: Row(
            children: [
              const Icon(Icons.hub, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text('GitHub Integration',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (github.isConnected)
                Row(
                  children: [
                    if (github.avatarUrl != null)
                      CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(github.avatarUrl!)),
                    const SizedBox(width: 8),
                    Text('@${github.username}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: ref.read(githubProvider.notifier).disconnect,
                      child: const Text('Disconnect',
                          style: TextStyle(
                              color: AppColors.accentRed, fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Main content
        Expanded(
          child: github.isConnected
              ? _ConnectedView(github: github)
              : _ConnectView(
                  tokenController: _tokenController,
                  obscureToken: _obscureToken,
                  onToggleObscure: () =>
                      setState(() => _obscureToken = !_obscureToken),
                  onConnect: () {
                    if (_tokenController.text.isNotEmpty) {
                      ref
                          .read(githubProvider.notifier)
                          .connect(_tokenController.text);
                    }
                  },
                  error: github.error,
                ),
        ),
      ],
    );
  }
}

class _ConnectView extends StatelessWidget {
  final TextEditingController tokenController;
  final bool obscureToken;
  final VoidCallback onToggleObscure;
  final VoidCallback onConnect;
  final String? error;

  const _ConnectView({
    required this.tokenController,
    required this.obscureToken,
    required this.onToggleObscure,
    required this.onConnect,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hub,
                      size: 28, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connect GitHub',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text('Save your AI OS as a repo',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Benefits
            ...[
              ('💾', 'Backup your Cyborg configuration & knowledge base'),
              ('🔄', 'Sync across multiple devices via private repo'),
              ('📦', 'Version control your AI OS snapshots'),
              ('🤝', 'Share agents & workflows as open-source repos'),
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(item.$1, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.$2,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),
            const Text('Personal Access Token',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: tokenController,
              obscureText: obscureToken,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'JetBrainsMono'),
              decoration: InputDecoration(
                hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                prefixIcon: const Icon(Icons.key_outlined, size: 16),
                suffixIcon: IconButton(
                  icon: Icon(
                      obscureToken
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.accentRed, size: 14),
                            const SizedBox(width: 8),
                            const Text('Connection Error', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              'Token is stored securely using OS keychain. Never sent to any cloud.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.hub, size: 16),
                label: const Text('Connect to GitHub'),
                onPressed: onConnect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedView extends ConsumerWidget {
  final GitHubState github;
  const _ConnectedView({required this.github});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(githubProvider.notifier);

    if (github.vaultRepo == null) {
      return _VaultSetup(github: github);
    }

    if (github.selectedRepo != null) {
      return _RepoExplorer(github: github);
    }

    return Column(
      children: [
        if (github.lastError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentRed.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.accentRed, size: 18),
                    const SizedBox(width: 8),
                    const Text('Sync Issue Detected',
                        style: TextStyle(
                            color: AppColors.accentRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(github.lastError!,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12)),
                if (github.lastError!.contains('403')) ...[
                  const SizedBox(height: 12),
                  const Text('How to fix:',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  const SizedBox(height: 4),
                  const Text(
                      '1. Go to GitHub Settings > Developer Settings > Personal Access Tokens.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  const Text(
                      '2. Edit your token and ensure "repo" scope is checked.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  const Text(
                      '3. If using Fine-grained tokens, grant "Contents" Read & Write access.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ],
            ),
          ),
        // Vault Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.accent.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.psychology, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Vault: ${github.vaultRepo}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent),
                ),
              ),
              TextButton.icon(
                onPressed: github.isSyncing
                    ? null
                    : () => ref
                        .read(githubProvider.notifier)
                        .syncRepo(github.vaultRepo!),
                icon: github.isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(github.isSyncing ? 'Syncing...' : 'Sync All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showChangeVaultConfirm(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        // Sync bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_shared,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text('Active Vault Repository',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (github.isSyncing)
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('Syncing...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('Sync All', style: TextStyle(fontSize: 12)),
                  onPressed: () => notifier.syncRepo(github.vaultRepo!),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ),
        // Repos list (filtered to vault only)
        Expanded(
          child: github.repos.isEmpty
              ? const Center(
                  child: Text('Loading vault details...',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: github.repos
                      .where((r) => r.fullName == github.vaultRepo)
                      .map((repo) => Center(
                            child: SizedBox(
                              width: 500,
                              height: 140,
                              child: _RepoCard(
                                repo: repo,
                                isSyncing: github.isSyncing &&
                                    github.lastSyncedRepo == repo.name,
                                onSync: () => notifier.syncRepo(repo.fullName),
                                onTap: () => notifier.selectRepo(repo),
                              ),
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  void _showChangeVaultConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Active Vault?'),
        content: const Text(
          'Changing the vault will disconnect the current repository from your Second Brain. '
          'Existing data will remain on GitHub, but new data will sync to the new vault.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(githubProvider.notifier).clearVault();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Change Vault'),
          ),
        ],
      ),
    );
  }
}

class _VaultSetup extends StatefulWidget {
  final GitHubState github;
  const _VaultSetup({required this.github});

  @override
  State<_VaultSetup> createState() => _VaultSetupState();
}

class _VaultSetupState extends State<_VaultSetup> {
  final _newRepoCtrl = TextEditingController();

  @override
  void dispose() {
    _newRepoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.psychology, size: 48, color: AppColors.accent),
            const SizedBox(height: 24),
            const Text(
              'Select Your Second Brain Vault',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All your AI OS data, knowledge, and configurations will be stored securely in this GitHub repository.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Create New
            const Text('Create a new vault repository',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newRepoCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. cyborg-vault',
                      prefixText: 'cyborg-',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Consumer(builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: widget.github.isCreatingVault
                        ? null
                        : () => ref
                            .read(githubProvider.notifier)
                            .createVault('cyborg-${_newRepoCtrl.text}'),
                    child: widget.github.isCreatingVault
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Vault'),
                  );
                }),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Row(children: [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR',
                        style: TextStyle(color: AppColors.textMuted))),
                Expanded(child: Divider()),
              ]),
            ),

            // Select Existing
            const Text('Select an existing repository',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widget.github.repos.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.github.repos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final repo = widget.github.repos[i];
                          return Consumer(builder: (context, ref, _) {
                            return ListTile(
                              dense: true,
                              title: Text(repo.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(repo.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 16),
                              onTap: () => ref
                                  .read(githubProvider.notifier)
                                  .setVault(repo.fullName),
                            );
                          });
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoExplorer extends ConsumerWidget {
  final GitHubState github;
  const _RepoExplorer({required this.github});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(githubProvider.notifier);
    final repo = github.selectedRepo!;

    return Row(
      children: [
        // Left: File list (Shrinks when file is selected)
        Expanded(
          flex: github.selectedFile != null ? 1 : 3,
          child: Column(
            children: [
              // Explorer Header / Breadcrumbs
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surfaceVariant,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      onPressed: () => notifier.selectRepo(null),
                      tooltip: 'Back to repositories',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _breadcrumbItem(
                                repo.name, () => notifier.loadRepoContents('')),
                            if (github.currentPath.isNotEmpty) ...[
                              const Icon(Icons.chevron_right,
                                  size: 14, color: AppColors.textMuted),
                              ...github.currentPath
                                  .split('/')
                                  .asMap()
                                  .entries
                                  .map((e) {
                                final subPath = github.currentPath
                                    .split('/')
                                    .take(e.key + 1)
                                    .join('/');
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _breadcrumbItem(
                                        e.value,
                                        () =>
                                            notifier.loadRepoContents(subPath)),
                                    if (e.key <
                                        github.currentPath.split('/').length -
                                            1)
                                      const Icon(Icons.chevron_right,
                                          size: 14, color: AppColors.textMuted),
                                  ],
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (github.isLoadingContents)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // File list
              Expanded(
                child: github.isLoadingContents && github.repoContents.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: github.repoContents.length,
                        itemBuilder: (context, i) {
                          final item = github.repoContents[i];
                          return _FileItem(
                            item: item,
                            isSelected: github.selectedFile?.path == item.path,
                            onTap: () {
                              if (item.isDir) {
                                notifier.loadRepoContents(item.path);
                                notifier.selectFile(null);
                              } else {
                                notifier.selectFile(item);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // Right: File Content (Split view)
        if (github.selectedFile != null) ...[
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            flex: 2,
            child: _FileContentViewer(
              file: github.selectedFile!,
              content: github.selectedFileContent,
              isLoading: github.isLoadingFile,
              onClose: () => notifier.selectFile(null),
            ),
          ),
        ],
      ],
    );
  }

  Widget _breadcrumbItem(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent)),
      ),
    );
  }
}

class _FileItem extends StatelessWidget {
  final GitHubFile item;
  final bool isSelected;
  final VoidCallback onTap;

  const _FileItem({
    required this.item,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: AppColors.accent.withOpacity(0.1),
      leading: Icon(
        item.isDir ? Icons.folder : Icons.description_outlined,
        color: item.isDir
            ? Colors.amber
            : (isSelected ? AppColors.accent : AppColors.textSecondary),
        size: 18,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: item.isDir
          ? null
          : Text(_formatSize(item.size),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      onTap: onTap,
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FileContentViewer extends StatelessWidget {
  final GitHubFile file;
  final String? content;
  final bool isLoading;
  final VoidCallback onClose;

  const _FileContentViewer({
    required this.file,
    this.content,
    required this.isLoading,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Viewer Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface,
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                tooltip: 'Close preview',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: Container(
            color: AppColors.background,
            width: double.infinity,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : content == null
                    ? const Center(child: Text('No content available'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: file.name.toLowerCase().endsWith('.md')
                            ? MarkdownBody(
                                data: content!,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context))
                                    .copyWith(
                                  p: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13),
                                  code: const TextStyle(
                                    backgroundColor: AppColors.surfaceVariant,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : SelectableText(
                                content!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                      ),
          ),
        ),
      ],
    );
  }
}

class _RepoCard extends StatelessWidget {
  final GitHubRepo repo;
  final bool isSyncing;
  final VoidCallback onSync;
  final VoidCallback onTap;

  const _RepoCard({
    required this.repo,
    required this.isSyncing,
    required this.onSync,
    required this.onTap,
  });

  static const _langColors = {
    'Python': Color(0xFF3572A5),
    'Dart': Color(0xFF00B4AB),
    'TypeScript': Color(0xFF3178C6),
    'JavaScript': Color(0xFFF7DF1E),
    'Rust': Color(0xFFDEA584),
    'Go': Color(0xFF00ADD8),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    repo.private
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(repo.name,
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, size: 14),
                    onPressed: isSyncing ? null : onSync,
                    tooltip: 'Sync to Cyborg',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (repo.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(repo.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              const Expanded(
                  child: SizedBox()), // Flexible space instead of Spacer
              Row(
                children: [
                  if (repo.language != 'Unknown') ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _langColors[repo.language] ?? AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(repo.language,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 10),
                  ],
                  const Icon(Icons.star_outline,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('${repo.stars}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
