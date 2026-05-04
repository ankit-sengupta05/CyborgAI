import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/providers/app_providers.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded }

enum ServerStatus { stopped, starting, running }

class ModelInfo {
  final String id;
  final String name;
  final double sizeGb;
  final String quantization;
  final String taskType;
  final double rating;
  final int downloads;
  final DownloadStatus downloadStatus;
  final double downloadProgress;
  final bool isLoaded;
  final bool isLoading;
  final String? path;
  final String source; // 'local', 'external', 'catalog'

  const ModelInfo({
    required this.id,
    required this.name,
    required this.sizeGb,
    required this.quantization,
    required this.taskType,
    this.rating = 0,
    this.downloads = 0,
    this.downloadStatus = DownloadStatus.notDownloaded,
    this.downloadProgress = 0,
    this.isLoaded = false,
    this.isLoading = false,
    this.path,
    this.source = 'catalog',
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
        id: json['id'],
        name: json['name'],
        sizeGb: (json['size_gb'] ?? 0).toDouble(),
        quantization: json['quantization'] ?? 'Q4_K_M',
        taskType: json['task_type'] ?? 'text-generation',
        rating: (json['rating'] ?? 4.5).toDouble(),
        downloads: json['downloads'] ?? 0,
        downloadStatus: json['downloaded'] == true
            ? DownloadStatus.downloaded
            : DownloadStatus.notDownloaded,
        isLoaded: json['loaded'] ?? false,
        path: json['path'],
        source: json['source'] ?? 'catalog',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size_gb': sizeGb,
        'quantization': quantization,
        'task_type': taskType,
        'rating': rating,
        'downloads': downloads,
        'downloaded': downloadStatus == DownloadStatus.downloaded,
        'loaded': isLoaded,
        'path': path,
      };

  ModelInfo copyWith({
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    bool? isLoaded,
    bool? isLoading,
    String? path,
  }) =>
      ModelInfo(
        id: id,
        name: name,
        sizeGb: sizeGb,
        quantization: quantization,
        taskType: taskType,
        rating: rating,
        downloads: downloads,
        downloadStatus: downloadStatus ?? this.downloadStatus,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        isLoaded: isLoaded ?? this.isLoaded,
        isLoading: isLoading ?? this.isLoading,
        path: path ?? this.path,
        source: source,
      );
}

class ModelManagerState {
  final List<ModelInfo> availableModels;
  final List<ModelInfo> downloadedModels;
  final ServerStatus serverStatus;
  final String serverUrl;
  final int serverPort;
  final String searchQuery;
  final String? selectedModelForHosting;
  final int activeTab;
  final int nCtx;
  final int nGpuLayers;
  final int nThreads;
  final int nBatch;

  const ModelManagerState({
    this.availableModels = const [],
    this.downloadedModels = const [],
    this.serverStatus = ServerStatus.stopped,
    this.serverUrl = 'http://127.0.0.1',
    this.serverPort = 1234,
    this.searchQuery = '',
    this.selectedModelForHosting,
    this.activeTab = 0,
    this.nCtx = 4096,
    this.nGpuLayers = -1,
    this.nThreads = 0, // 0 = auto
    this.nBatch = 512,
  });

  ModelManagerState copyWith({
    List<ModelInfo>? availableModels,
    List<ModelInfo>? downloadedModels,
    ServerStatus? serverStatus,
    String? serverUrl,
    int? serverPort,
    String? searchQuery,
    String? selectedModelForHosting,
    int? activeTab,
    int? nCtx,
    int? nGpuLayers,
    int? nThreads,
    int? nBatch,
  }) =>
      ModelManagerState(
        availableModels: availableModels ?? this.availableModels,
        downloadedModels: downloadedModels ?? this.downloadedModels,
        serverStatus: serverStatus ?? this.serverStatus,
        serverUrl: serverUrl ?? this.serverUrl,
        serverPort: serverPort ?? this.serverPort,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedModelForHosting:
            selectedModelForHosting ?? this.selectedModelForHosting,
        activeTab: activeTab ?? this.activeTab,
        nCtx: nCtx ?? this.nCtx,
        nGpuLayers: nGpuLayers ?? this.nGpuLayers,
        nThreads: nThreads ?? this.nThreads,
        nBatch: nBatch ?? this.nBatch,
      );
}

class ModelManagerNotifier extends StateNotifier<ModelManagerState> {
  final Ref ref;
  final _box = Hive.box('cyborg_cache');

  ModelManagerNotifier(this.ref) : super(const ModelManagerState()) {
    _loadModels();
  }

  final _dio = apiDio;

  // Predefined popular models for browsing
  static const _catalog = [
    {
      'id': 'gemma-4-e2b-it-q8-0',
      'name': 'Gemma 4 E2B (Recommended)',
      'size_gb': 4.6,
      'quantization': 'Q8_0',
      'task_type': 'text-generation',
      'rating': 5.0,
      'downloads': 1000,
      'hf_repo': 'google/gemma-2-2b-it-GGUF',
      'filename': 'gemma-4-e2b-it-Q8_0.gguf'
    },
    {
      'id': 'qwen2.5-1.5b-instruct-q4',
      'name': 'Qwen2.5 1.5B Instruct',
      'size_gb': 1.1,
      'quantization': 'Q4_K_M',
      'task_type': 'instruct',
      'rating': 4.8,
      'downloads': 56000,
      'hf_repo': 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      'filename': 'qwen2.5-1.5b-instruct-q4_k_m.gguf'
    },
    {
      'id': 'qwen2.5-coder-14b-q4',
      'name': 'Qwen2.5-Coder 14B',
      'size_gb': 8.4,
      'quantization': 'Q4_K_M',
      'task_type': 'code',
      'rating': 4.9,
      'downloads': 124000,
      'hf_repo': 'Qwen/Qwen2.5-Coder-14B-Instruct-GGUF',
      'filename': 'qwen2.5-coder-14b-instruct-q4_k_m.gguf'
    },
    {
      'id': 'llama-3.2-8b-q4',
      'name': 'Llama 3.2 8B',
      'size_gb': 4.7,
      'quantization': 'Q4_K_M',
      'task_type': 'text-generation',
      'rating': 4.7,
      'downloads': 98000,
      'hf_repo': 'meta-llama/Llama-3.2-8B-Instruct-GGUF',
      'filename': 'llama-3.2-8b-instruct-q4_k_m.gguf'
    },
    {
      'id': 'mistral-7b-q4',
      'name': 'Mistral 7B Instruct',
      'size_gb': 4.1,
      'quantization': 'Q4_K_M',
      'task_type': 'instruct',
      'rating': 4.6,
      'downloads': 89000,
      'hf_repo': 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF',
      'filename': 'mistral-7b-instruct-v0.2.Q4_K_M.gguf'
    },
    {
      'id': 'phi-3.5-mini-q4',
      'name': 'Phi-3.5 Mini',
      'size_gb': 2.2,
      'quantization': 'Q4_K_M',
      'task_type': 'text-generation',
      'rating': 4.5,
      'downloads': 45000,
      'hf_repo': 'microsoft/Phi-3.5-mini-instruct-gguf',
      'filename': 'Phi-3.5-mini-instruct-Q4_K_M.gguf'
    },
    {
      'id': 'deepseek-r1-7b-q4',
      'name': 'DeepSeek-R1 7B',
      'size_gb': 4.7,
      'quantization': 'Q4_K_M',
      'task_type': 'reasoning',
      'rating': 4.8,
      'downloads': 67000,
      'hf_repo': 'deepseek-ai/DeepSeek-R1-Distill-Qwen-7B-GGUF',
      'filename': 'deepseek-r1-distill-qwen-7b-q4_k_m.gguf'
    },
    {
      'id': 'gemma2-9b-q4',
      'name': 'Gemma 2 9B',
      'size_gb': 5.4,
      'quantization': 'Q4_K_M',
      'task_type': 'text-generation',
      'rating': 4.6,
      'downloads': 52000,
      'hf_repo': 'google/gemma-2-9b-it-GGUF',
      'filename': 'gemma-2-9b-it-Q4_K_M.gguf'
    },
    {
      'id': 'codestral-22b-q4',
      'name': 'Codestral 22B',
      'size_gb': 12.4,
      'quantization': 'Q4_K_M',
      'task_type': 'code',
      'rating': 4.8,
      'downloads': 38000,
      'hf_repo': 'bartowski/Codestral-22B-v0.1-GGUF',
      'filename': 'Codestral-22B-v0.1-Q4_K_M.gguf'
    },
    {
      'id': 'moondream2',
      'name': 'Moondream2 (Vision)',
      'size_gb': 1.8,
      'quantization': 'Q8',
      'task_type': 'vision',
      'rating': 4.4,
      'downloads': 29000,
      'hf_repo': 'vikhyatk/moondream2',
      'filename': 'moondream2-text-model-f16.gguf'
    },
    {
      'id': 'gemma4-2b-litert',
      'name': 'Gemma 4 2B',
      'size_gb': 1.5,
      'quantization': 'LiteRT',
      'task_type': 'text-generation',
      'rating': 4.9,
      'downloads': 15000,
      'hf_repo': 'litert-community/gemma-4-E2B-it-litert-lm',
      'filename': 'gemma-4-E2B-it.litertlm'
    },
  ];

  void _saveLocalModels(List<ModelInfo> models) {
    _box.put('downloaded_models',
        jsonEncode(models.map((m) => m.toJson()).toList()));
  }

  Future<void> _loadModels() async {
    final catalog = _catalog.map((m) => ModelInfo.fromJson({...m})).toList();
    state = state.copyWith(availableModels: catalog);

    List<ModelInfo> localModels = [];
    // Load locally saved
    try {
      final data = _box.get('downloaded_models');
      if (data != null) {
        final List list = jsonDecode(data);
        localModels = list
            .map((m) => ModelInfo.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        state = state.copyWith(downloadedModels: localModels);
      }
    } catch (_) {}

    try {
      final resp = await _dio.get(ApiConstants.modelsList);
      final serverDownloaded = (resp.data['models'] as List)
          .map((m) => ModelInfo.fromJson(m))
          .toList();

      // Keep any models that have quantization == 'Custom' and are not in serverDownloaded
      final customModels =
          localModels.where((m) => m.quantization == 'Custom').toList();
      final Map<String, ModelInfo> merged = {};

      for (var m in serverDownloaded) merged[m.path ?? m.id] = m;
      for (var m in customModels) merged[m.path ?? m.id] = m;

      final updated = merged.values.toList();
      state = state.copyWith(downloadedModels: updated);
      _saveLocalModels(updated);
    } catch (_) {}
  }

  Future<void> downloadModel(String id) async {
    final idx = state.availableModels.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    final updated = List<ModelInfo>.from(state.availableModels);
    updated[idx] = updated[idx].copyWith(
      downloadStatus: DownloadStatus.downloading,
      downloadProgress: 0,
    );
    state = state.copyWith(availableModels: updated);

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Direct download to mobile device bypassing the Windows backend
        final catalogEntry =
            _catalog.firstWhere((e) => e['id'] == id, orElse: () => {});
        final hfRepo = catalogEntry['hf_repo'] as String?;
        final filename = catalogEntry['filename'] as String? ?? 'model.gguf';

        if (hfRepo == null) {
          throw Exception('HuggingFace Repo not found for direct download');
        }

        final url = 'https://huggingface.co/$hfRepo/resolve/main/$filename';
        final dir = await getApplicationDocumentsDirectory();
        final savePath = '${dir.path}/models/$id/$filename';

        await Directory('${dir.path}/models/$id').create(recursive: true);

        await Dio().download(url, savePath, onReceiveProgress: (rec, total) {
          if (total > 0) {
            final progress = rec / total;
            final updatedProgress = List<ModelInfo>.from(state.availableModels);
            final progIdx = updatedProgress.indexWhere((m) => m.id == id);
            if (progIdx >= 0) {
              updatedProgress[progIdx] = updatedProgress[progIdx].copyWith(
                downloadProgress: progress,
              );
              state = state.copyWith(availableModels: updatedProgress);
            }
          }
        });

        // Add to downloaded models
        final downloaded = List<ModelInfo>.from(state.downloadedModels);
        final customModel = ModelInfo(
          id: id,
          name: catalogEntry['name'] as String? ?? id,
          sizeGb: (catalogEntry['size_gb'] as num?)?.toDouble() ?? 0,
          quantization: catalogEntry['quantization'] as String? ?? 'GGUF',
          taskType: catalogEntry['task_type'] as String? ?? 'unknown',
          isLoaded: false,
          downloadStatus: DownloadStatus.downloaded,
          path: savePath,
        );
        downloaded.insert(0, customModel);
        state = state.copyWith(downloadedModels: downloaded);
        _saveLocalModels(downloaded);
      } else {
        if (id.contains('/')) {
          await _dio.post('${ApiConstants.modelsDownload}/repo',
              queryParameters: {'repo_id': id});
        } else {
          await _dio.post('${ApiConstants.modelsDownload}/$id');
        }
      }

      final finalIdx = state.availableModels.indexWhere((m) => m.id == id);
      if (finalIdx >= 0) {
        final finalUpdated = List<ModelInfo>.from(state.availableModels);
        finalUpdated[finalIdx] = finalUpdated[finalIdx].copyWith(
          downloadStatus: DownloadStatus.downloaded,
          downloadProgress: 1.0,
        );
        state = state.copyWith(availableModels: finalUpdated);
      }

      if (!Platform.isAndroid && !Platform.isIOS) {
        await _loadModels();
      }
    } catch (e) {
      debugPrint("Download failed: $e");
      final errIdx = state.availableModels.indexWhere((m) => m.id == id);
      if (errIdx >= 0) {
        final errUpdated = List<ModelInfo>.from(state.availableModels);
        errUpdated[errIdx] = errUpdated[errIdx].copyWith(
          downloadStatus: DownloadStatus.notDownloaded,
        );
        state = state.copyWith(availableModels: errUpdated);
      }
    }
  }

  Future<void> loadModel(String id) async {
    final model = state.downloadedModels.firstWhere((m) => m.id == id);

    // Optimistic update: set target model to loading state
    final loadingModels = state.downloadedModels
        .map((m) => m.copyWith(
            isLoading: m.id == id, isLoaded: m.id == id ? false : m.isLoaded))
        .toList();
    state = state.copyWith(downloadedModels: loadingModels);

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (model.path != null) {
          await ref.read(inferenceBackendProvider).loadModel(model.path!);
        }
      } else {
        // On Windows, use path if source is local, otherwise use id
        final loadId = (model.source == 'local' && model.path != null)
            ? model.path!
            : model.id;
        final resp =
            await _dio.post('${ApiConstants.modelsLoad}/$loadId', data: {
          'n_ctx': state.nCtx,
          'n_gpu_layers': state.nGpuLayers,
          'n_threads': state.nThreads > 0 ? state.nThreads : null,
          'n_batch': state.nBatch,
        });

        if (resp.data['status'] == 'downloading') {
          ref.read(globalErrorProvider.notifier).state =
              resp.data['message'] ?? 'Model is downloading...';
          return;
        }
      }

      // GROUND TRUTH: Refresh all models from the server to ensure UI is perfectly synced
      await _loadModels();
    } catch (e) {
      debugPrint("Load failed: $e");
      String msg = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          msg = data['detail']?.toString() ?? e.message ?? e.toString();
        } else {
          msg = data?.toString() ?? e.message ?? e.toString();
        }
      }
      ref.read(globalErrorProvider.notifier).state = 'Load failed: $msg';
    } finally {
      // Clear loading state
      final reset = state.downloadedModels
          .map((m) => m.copyWith(isLoading: false))
          .toList();
      state = state.copyWith(downloadedModels: reset);
    }
  }

  Future<void> loadCustomModel(String path) async {
    try {
      final modelId = path.split(RegExp(r'[\\/]')).last.replaceAll(
          RegExp(r'\.(gguf|litertlm|tflite|task|bin)$', caseSensitive: false),
          '');

      final file = File(path);
      double sizeGb = 0.0;
      if (file.existsSync()) {
        sizeGb = file.lengthSync() / (1024 * 1024 * 1024);
      }

      // Route via inference backend interface (handles HTTP vs FFI automatically)
      await ref.read(inferenceBackendProvider).loadModel(path);

      final downloaded = state.downloadedModels
          .map((m) => m.copyWith(isLoaded: false))
          .toList();

      final customModel = ModelInfo(
        id: modelId,
        name: modelId,
        sizeGb: sizeGb,
        quantization: 'Custom',
        taskType: 'unknown',
        isLoaded: true,
        downloadStatus: DownloadStatus.downloaded,
        path: path,
      );

      final updated = [...downloaded, customModel];
      _saveLocalModels(updated);
      state = state.copyWith(downloadedModels: updated);
    } catch (e) {
      debugPrint('Error loading custom model: $e');
      ref.read(globalErrorProvider.notifier).state = 'Failed to load model: $e';
    }
  }

  Future<void> unloadModel(String id) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ref.read(inferenceBackendProvider).stop();
      } else {
        await _dio.post('${ApiConstants.modelsUnload}/$id');
      }
      final downloaded = state.downloadedModels
          .map((m) => m.copyWith(isLoaded: false))
          .toList();
      state = state.copyWith(downloadedModels: downloaded);
      _saveLocalModels(downloaded);
    } catch (e) {
      debugPrint("Unload failed: $e");
    }
  }

  Future<void> startServer() async {
    state = state.copyWith(serverStatus: ServerStatus.starting);
    try {
      await _dio.post(ApiConstants.serverStart, data: {
        'port': state.serverPort,
        'model_path': state.selectedModelForHosting,
      });
      state = state.copyWith(serverStatus: ServerStatus.running);
    } catch (_) {
      state = state.copyWith(serverStatus: ServerStatus.stopped);
    }
  }

  void setHostingModel(String? path) {
    state = state.copyWith(selectedModelForHosting: path);
  }

  Future<void> stopServer() async {
    await _dio.post(ApiConstants.serverStop);
    state = state.copyWith(serverStatus: ServerStatus.stopped);
  }

  Future<void> updateExternalServer(String url) async {
    state = state.copyWith(serverStatus: ServerStatus.starting);
    try {
      final resp = await _dio.post(ApiConstants.serverConfig, data: {
        'url': url,
      });
      if (resp.data['status'] == 'connected') {
        state = state.copyWith(
          serverStatus: ServerStatus.running,
          serverUrl: url.split('://').last.split(':').first,
        );
        // Refresh models as we are now connected to a new server
        await _loadModels();
      }
    } catch (e) {
      state = state.copyWith(serverStatus: ServerStatus.stopped);
      ref.read(globalErrorProvider.notifier).state = 'Connection failed: $e';
    }
  }

  void setServerPort(int port) {
    state = state.copyWith(serverPort: port);
  }

  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setTab(int tab) => state = state.copyWith(activeTab: tab);
  void setNCtx(int val) => state = state.copyWith(nCtx: val);
  void setNGpuLayers(int val) => state = state.copyWith(nGpuLayers: val);
  void setNThreads(int val) => state = state.copyWith(nThreads: val);
  void setNBatch(int val) => state = state.copyWith(nBatch: val);
}

final modelManagerProvider =
    StateNotifierProvider<ModelManagerNotifier, ModelManagerState>((ref) {
  return ModelManagerNotifier(ref);
});

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      ref.read(modelManagerProvider.notifier).setTab(_tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with tabs
        Container(
          color: AppColors.surface,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.memory_outlined,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    const Text('Model Manager',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorWeight: 2,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Browse'),
                  Tab(text: 'Downloaded'),
                  Tab(text: 'Server'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _BrowseTab(),
              _DownloadedTab(),
              _ServerTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrowseTab extends ConsumerStatefulWidget {
  const _BrowseTab();

  @override
  ConsumerState<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends ConsumerState<_BrowseTab> {
  final _searchController = TextEditingController();
  final _repoController = TextEditingController();
  String _selectedFilter = 'All';
  static const _filters = ['All', 'Code', 'Text', 'Vision', 'Reasoning'];

  @override
  void dispose() {
    _searchController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelManagerProvider);
    final notifier = ref.read(modelManagerProvider.notifier);

    final filtered = state.availableModels.where((m) {
      final matchesSearch = state.searchQuery.isEmpty ||
          m.name.toLowerCase().contains(state.searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' ||
          m.taskType.toLowerCase().contains(_selectedFilter.toLowerCase());
      return matchesSearch && matchesFilter;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: notifier.setSearch,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search models...',
                  prefixIcon: Icon(Icons.search, size: 16),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final isSelected = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              // Manual Download Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Download from Hugging Face',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _repoController,
                            onSubmitted: (val) {
                              if (val.isNotEmpty) {
                                notifier.downloadModel(val);
                                _repoController.clear();
                              }
                            },
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'user/repo-id',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_repoController.text.isNotEmpty) {
                              notifier.downloadModel(_repoController.text);
                              _repoController.clear();
                            }
                          },
                          child:
                              const Text('Go', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              return _ModelCard(
                model: filtered[i],
                onDownload: () => notifier.downloadModel(filtered[i].id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  final ModelInfo model;
  final VoidCallback onDownload;

  const _ModelCard({required this.model, required this.onDownload});

  static const _taskColors = {
    'code': AppColors.accentGreen,
    'vision': AppColors.accentPurple,
    'reasoning': AppColors.accentOrange,
  };

  @override
  Widget build(BuildContext context) {
    final taskColor = _taskColors[model.taskType] ?? AppColors.accent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: taskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    model.taskType == 'code'
                        ? Icons.code
                        : model.taskType == 'vision'
                            ? Icons.visibility
                            : Icons.smart_toy,
                    color: taskColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _Chip('${model.sizeGb.toStringAsFixed(1)} GB'),
                          const SizedBox(width: 6),
                          _Chip(model.quantization),
                          const SizedBox(width: 6),
                          _Chip(model.taskType, color: taskColor),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildDownloadButton(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: AppColors.accentYellow),
                const SizedBox(width: 4),
                Text('${model.rating}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.download_outlined,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(_formatDownloads(model.downloads),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            if (model.downloadStatus == DownloadStatus.downloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: model.downloadProgress,
                  minHeight: 4,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    switch (model.downloadStatus) {
      case DownloadStatus.notDownloaded:
        return ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 14),
          label: const Text('Download', style: TextStyle(fontSize: 12)),
          onPressed: onDownload,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.downloaded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 14, color: AppColors.accentGreen),
              SizedBox(width: 4),
              Text('Downloaded',
                  style: TextStyle(color: AppColors.accentGreen, fontSize: 11)),
            ],
          ),
        );
    }
  }

  String _formatDownloads(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textMuted).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color ?? AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DownloadedTab extends ConsumerWidget {
  const _DownloadedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelManagerProvider);
    final notifier = ref.read(modelManagerProvider.notifier);
    final loadedModel = state.downloadedModels.firstWhere((m) => m.isLoaded,
        orElse: () => const ModelInfo(
            id: '', name: '', sizeGb: 0, quantization: '', taskType: ''));

    return Column(
      children: [
        if (loadedModel.id.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.accentGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loaded: ${loadedModel.name}',
                    style: const TextStyle(
                      color: AppColors.accentGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => notifier.unloadModel(loadedModel.id),
                  child: const Text('Unload', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        Expanded(
          child: state.downloadedModels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('No models downloaded',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      const Text(
                          'Browse the catalog to download models or load manually',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Load from folder'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                          );
                          if (result != null &&
                              result.files.single.path != null) {
                            final path = result.files.single.path!;
                            final ext = path.toLowerCase();
                            if (ext.endsWith('.gguf') ||
                                ext.endsWith('.litertlm') ||
                                ext.endsWith('.tflite') ||
                                ext.endsWith('.task') ||
                                ext.endsWith('.bin')) {
                              try {
                                await ref
                                    .read(modelManagerProvider.notifier)
                                    .loadCustomModel(path);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Failed to load: $e'),
                                        backgroundColor: AppColors.accentRed),
                                  );
                                }
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please select a valid model file (.gguf, .litertlm, etc)')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.folder_open, size: 14),
                            label: const Text('Load Model from folder',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.any,
                              );
                              if (result != null &&
                                  result.files.single.path != null) {
                                final path = result.files.single.path!;
                                final ext = path.toLowerCase();
                                if (ext.endsWith('.gguf') ||
                                    ext.endsWith('.litertlm') ||
                                    ext.endsWith('.tflite') ||
                                    ext.endsWith('.task') ||
                                    ext.endsWith('.bin')) {
                                  try {
                                    await ref
                                        .read(modelManagerProvider.notifier)
                                        .loadCustomModel(path);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Failed to load: $e'),
                                            backgroundColor:
                                                AppColors.accentRed),
                                      );
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please select a valid model file (.gguf, .litertlm, etc)')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: state.downloadedModels.length,
                        itemBuilder: (context, i) {
                          final model = state.downloadedModels[i];
                          return ListTile(
                            tileColor: model.isLoaded
                                ? AppColors.accentGreen.withOpacity(0.05)
                                : null,
                            leading: Icon(
                              model.isLoaded
                                  ? Icons.play_circle_filled
                                  : Icons.smart_toy_outlined,
                              color: model.isLoaded
                                  ? AppColors.accentGreen
                                  : AppColors.textSecondary,
                              size: 22,
                            ),
                            title: Text(model.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13)),
                            subtitle: Text(
                              '${model.sizeGb.toStringAsFixed(1)} GB • ${model.quantization}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.folder_open_outlined,
                                      size: 18, color: AppColors.textSecondary),
                                  tooltip: 'Locate in File Explorer',
                                  onPressed: () {
                                    if (model.path != null) {
                                      if (Platform.isWindows) {
                                        Process.run('explorer.exe',
                                            ['/select,', model.path!]);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'File exploring is only supported on Windows.')),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Model path is unknown.')),
                                      );
                                    }
                                  },
                                ),
                                if (model.isLoaded)
                                  IconButton(
                                    icon: const Icon(Icons.stop_circle_outlined,
                                        size: 18),
                                    onPressed: () =>
                                        notifier.unloadModel(model.id),
                                  )
                                else if (model.isLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accent),
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon:
                                        const Icon(Icons.play_arrow, size: 18),
                                    onPressed: () =>
                                        notifier.loadModel(model.id),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ServerTab extends ConsumerStatefulWidget {
  const _ServerTab();

  @override
  ConsumerState<_ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends ConsumerState<_ServerTab> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(modelManagerProvider);
    _urlController = TextEditingController(
        text: state.serverUrl.contains(':')
            ? 'http://${state.serverUrl}/v1'
            : 'http://localhost:1234/v1');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelManagerProvider);
    final notifier = ref.read(modelManagerProvider.notifier);
    final isRunning = state.serverStatus == ServerStatus.running;
    final isStarting = state.serverStatus == ServerStatus.starting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRunning
                              ? AppColors.accentGreen
                              : isStarting
                                  ? AppColors.accentYellow
                                  : AppColors.accentRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRunning
                            ? 'Server Running'
                            : isStarting
                                ? 'Starting...'
                                : 'Server Stopped',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isRunning) ...[
                    _ServerInfoRow('Endpoint',
                        '${state.serverUrl}:${state.serverPort}/v1'),
                    _ServerInfoRow('API Format', 'OpenAI Compatible'),
                    _ServerInfoRow('Protocol', 'HTTP/WebSocket'),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!isRunning)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Start Server'),
                          onPressed: isStarting ? null : notifier.startServer,
                        )
                      else
                        OutlinedButton.icon(
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('Stop Server'),
                          onPressed: notifier.stopServer,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // External Server card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Link External Server (LM Studio / Ollama)',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _urlController,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'http://localhost:1234/v1',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                          onFieldSubmitted: (val) {
                            if (val.isNotEmpty) {
                              notifier.updateExternalServer(val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isStarting
                            ? null
                            : () {
                                if (_urlController.text.isNotEmpty) {
                                  notifier.updateExternalServer(
                                      _urlController.text);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: Text(isStarting ? '...' : 'Connect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect to LM Studio, Ollama, or any OpenAI-compatible API.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Config card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Local Server Configuration',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  // Model selection
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Model to Host',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: state.selectedModelForHosting ??
                                  (state.downloadedModels.isNotEmpty
                                      ? state.downloadedModels.first.path
                                      : null),
                              isExpanded: true,
                              dropdownColor: AppColors.surface,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13),
                              hint: const Text('Select a model...',
                                  style: TextStyle(color: AppColors.textMuted)),
                              onChanged: isRunning || isStarting
                                  ? null
                                  : (val) {
                                      notifier.setHostingModel(val);
                                    },
                              items: state.downloadedModels.map((m) {
                                return DropdownMenuItem(
                                  value: m.path,
                                  child: Text(m.name,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _ServerInfoRow('Host', '127.0.0.1'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Port',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: state.serverPort.toString(),
                            enabled: !isRunning && !isStarting,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                            onChanged: (val) {
                              final p = int.tryParse(val);
                              if (p != null) {
                                notifier.setServerPort(p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ConfigInputRow('Context Length', state.nCtx.toString(),
                      (val) => notifier.setNCtx(int.tryParse(val) ?? 4096)),
                  _ConfigInputRow(
                      'GPU Layers (-1=Auto)',
                      state.nGpuLayers.toString(),
                      (val) => notifier.setNGpuLayers(int.tryParse(val) ?? -1)),
                  _ConfigInputRow('Threads (0=Auto)', state.nThreads.toString(),
                      (val) => notifier.setNThreads(int.tryParse(val) ?? 0)),
                  _ConfigInputRow('Batch Size', state.nBatch.toString(),
                      (val) => notifier.setNBatch(int.tryParse(val) ?? 512)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigInputRow extends StatelessWidget {
  final String label;
  final String value;
  final Function(String) onChanged;
  const _ConfigInputRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: value,
              keyboardType: TextInputType.number,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _ServerInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}
