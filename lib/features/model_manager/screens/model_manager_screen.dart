import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dio/dio.dart' as hf_dio;
import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../theme/paperclip_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/providers/app_providers.dart';

// Local shim so existing AppColors references resolve without rewriting every line
class AppColors {
  static const Color backgroundMain    = PaperclipTheme.backgroundDark;
  static const Color backgroundSidebar = PaperclipTheme.sidebarDark;
  static const Color backgroundSurface = PaperclipTheme.surfaceDark;
  static const Color backgroundInput   = PaperclipTheme.surfaceElevatedDark;
  static const Color borderDefault     = PaperclipTheme.borderDark;
  static const Color borderHover       = PaperclipTheme.borderBrightDark;
  static const Color textPrimary       = PaperclipTheme.foregroundDark;
  static const Color textSecondary     = PaperclipTheme.mutedDark;
  static const Color textTertiary      = PaperclipTheme.mutedFgDark;
  static const Color textMuted         = PaperclipTheme.mutedFgDark;
  static const Color accentBlue        = PaperclipTheme.accentCyan;
  static const Color accentBlueHover   = Color(0xFF00A0D6);
  static const Color accent            = PaperclipTheme.accentCyan;
  static const Color accentPurple      = PaperclipTheme.accentPurple;
  static const Color accentGreen       = PaperclipTheme.accentGreen;
  static const Color accentRed         = PaperclipTheme.accentRed;
  static const Color accentOrange      = PaperclipTheme.accentAmber;
  static const Color accentYellow      = PaperclipTheme.accentAmber;
  static const Color success           = PaperclipTheme.accentGreen;
  static const Color warning           = PaperclipTheme.accentAmber;
  static const Color error             = PaperclipTheme.accentRed;
  static const Color info              = PaperclipTheme.accentCyan;
  static const Color surface           = PaperclipTheme.surfaceDark;
  static const Color surfaceVariant    = PaperclipTheme.surfaceElevatedDark;
  static const Color background        = PaperclipTheme.backgroundDark;
  static const Color border            = PaperclipTheme.borderDark;
  static const LinearGradient accentGradient = LinearGradient(
    colors: [PaperclipTheme.accentGreen, PaperclipTheme.accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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
  final String? mmproj_path;    // CLIP projector for vision models
  final bool supportsVision;    // true when mmproj is present
  final String source; // 'local', 'external', 'catalog', 'lmstudio'

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
    this.mmproj_path,
    this.supportsVision = false,
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
        mmproj_path: json['mmproj_path'],
        supportsVision: json['supports_vision'] ?? false,
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
        'mmproj_path': mmproj_path,
        'supports_vision': supportsVision,
        'source': source,
      };

  ModelInfo copyWith({
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    bool? isLoaded,
    bool? isLoading,
    String? path,
    String? mmproj_path,
    bool? supportsVision,
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
        mmproj_path: mmproj_path ?? this.mmproj_path,
        supportsVision: supportsVision ?? this.supportsVision,
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
    this.nBatch = 2048,
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
    {
      'id': 'qwen2.5-coder-14b',
      'name': 'Qwen 2.5 Coder 14B',
      'size_gb': 8.5,
      'quantization': 'Q4_K_M',
      'task_type': 'code',
      'rating': 4.9,
      'downloads': 125000,
      'hf_repo': 'Qwen/Qwen2.5-Coder-14B-Instruct-GGUF',
      'filename': 'qwen2.5-coder-14b-instruct-q4_k_m.gguf'
    },
    {
      'id': 'qwen2.5-coder-32b',
      'name': 'Qwen 2.5 Coder 32B',
      'size_gb': 18.5,
      'quantization': 'Q4_K_M',
      'task_type': 'code',
      'rating': 5.0,
      'downloads': 85000,
      'hf_repo': 'Qwen/Qwen2.5-Coder-32B-Instruct-GGUF',
      'filename': 'qwen2.5-coder-32b-instruct-q4_k_m.gguf'
    },
    {
      'id': 'qwen2.5-coder-72b',
      'name': 'Qwen 2.5 Coder 72B',
      'size_gb': 42.0,
      'quantization': 'Q4_K_M',
      'task_type': 'code',
      'rating': 5.0,
      'downloads': 45000,
      'hf_repo': 'Qwen/Qwen2.5-Coder-72B-Instruct-GGUF',
      'filename': 'qwen2.5-coder-72b-instruct-q4_k_m.gguf'
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
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
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

      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
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
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (model.path != null) {
          await ref.read(inferenceBackendProvider).loadModel(model.path!);
        }
      } else {
        // On Windows, use path if available, otherwise use id
        final loadId = (model.source != 'external' && model.path != null)
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
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
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

// ═══════════════════════════════════════════════════════════════════════════
// UI LAYER — LM Studio-style redesign
// ═══════════════════════════════════════════════════════════════════════════

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() =>
      _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        // ── Top bar ────────────────────────────────────────────
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: PaperclipTheme.sidebarDark,
            border: Border(
                bottom: BorderSide(color: PaperclipTheme.borderDark, width: 1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.memory_outlined,
                  color: PaperclipTheme.accentCyan, size: 17),
              const SizedBox(width: 8),
              const Text('Models',
                  style: TextStyle(
                      color: PaperclipTheme.foregroundDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _HdrBtn(
                icon: Icons.search,
                label: 'Browse HuggingFace',
                onTap: () => _showHFDialog(context),
              ),
              const SizedBox(width: 8),
              _HdrBtn(
                icon: Icons.folder_open_outlined,
                label: 'Load File',
                onTap: () => _pickFile(context),
              ),
            ],
          ),
        ),
        // ── Tab bar ────────────────────────────────────────────
        Container(
          color: PaperclipTheme.sidebarDark,
          child: TabBar(
            controller: _tabController,
            labelColor: PaperclipTheme.accentCyan,
            unselectedLabelColor: PaperclipTheme.mutedFgDark,
            indicatorColor: PaperclipTheme.accentCyan,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w400),
            tabs: const [
              Tab(text: 'My Models'),
              Tab(text: 'LM Studio'),
              Tab(text: 'Server'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        const Divider(height: 1, color: PaperclipTheme.borderDark),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MyModelsTab(),
              _LmStudioTab(),
              _ServerTab(),
              _SettingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  void _showHFDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _HFSearchDialog(),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.info_outline, color: PaperclipTheme.accentCyan, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('Custom local file loading is only supported on native desktop app.', style: TextStyle(fontSize: 12))),
        ]),
        backgroundColor: PaperclipTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result?.files.single.path == null) return;
    final path = result!.files.single.path!;
    final ext = path.toLowerCase();
    if (ext.endsWith('.gguf') ||
        ext.endsWith('.bin') ||
        ext.endsWith('.tflite') ||
        ext.endsWith('.task') ||
        ext.endsWith('.litertlm')) {
      try {
        await ref
            .read(modelManagerProvider.notifier)
            .loadCustomModel(path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle,
                  color: PaperclipTheme.accentGreen, size: 16),
              SizedBox(width: 8),
              Text('Model loaded'),
            ]),
            backgroundColor: PaperclipTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: PaperclipTheme.accentRed));
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Select a valid model file (.gguf, .bin, etc)')));
      }
    }
  }
}

// ─── Header Button ────────────────────────────────────────────────────────────

class _HdrBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HdrBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  State<_HdrBtn> createState() => _HdrBtnState();
}

class _HdrBtnState extends State<_HdrBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _h
                ? PaperclipTheme.surfaceDark
                : PaperclipTheme.surfaceElevatedDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: PaperclipTheme.borderDark, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 14, color: PaperclipTheme.mutedDark),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: PaperclipTheme.mutedDark)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── My Models Tab ────────────────────────────────────────────────────────────

class _MyModelsTab extends ConsumerWidget {
  const _MyModelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelManagerProvider);
    final notifier = ref.read(modelManagerProvider.notifier);

    if (state.downloadedModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PaperclipTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PaperclipTheme.borderDark),
              ),
              child: const Icon(Icons.inbox_outlined,
                  size: 30, color: PaperclipTheme.mutedFgDark),
            ),
            const SizedBox(height: 16),
            const Text('No models loaded',
                style: TextStyle(
                    color: PaperclipTheme.mutedDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text(
                'Browse HuggingFace or load a local .gguf file',
                style: TextStyle(
                    color: PaperclipTheme.mutedFgDark, fontSize: 12)),
          ],
        ),
      );
    }

    final loaded = state.downloadedModels
        .where((m) => m.isLoaded)
        .firstOrNull;

    return Column(
      children: [
        if (loaded != null)
          _LoadedBanner(
              model: loaded,
              onUnload: () => notifier.unloadModel(loaded.id)),
        // Column headers
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          decoration: const BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: PaperclipTheme.borderDark, width: 1))),
          child: Row(
            children: [
              const Expanded(
                  child: Text('Model',
                      style: TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5))),
              SizedBox(
                  width: 80,
                  child: Text('Quant',
                      style: const TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600))),
              SizedBox(
                  width: 60,
                  child: Text('Vision',
                      style: const TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600))),
              SizedBox(
                  width: 70,
                  child: Text('Size',
                      style: const TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 90),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: state.downloadedModels.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: PaperclipTheme.borderDark,
                indent: 16,
                endIndent: 16),
            itemBuilder: (context, i) {
              final m = state.downloadedModels[i];
              return _ModelRow(
                model: m,
                onLoad: () => notifier.loadModel(m.id),
                onUnload: () => notifier.unloadModel(m.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoadedBanner extends StatelessWidget {
  final ModelInfo model;
  final VoidCallback onUnload;
  const _LoadedBanner(
      {required this.model, required this.onUnload});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PaperclipTheme.accentGreen.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: PaperclipTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_filled,
              color: PaperclipTheme.accentGreen, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Active: ${model.name}',
                style: const TextStyle(
                    color: PaperclipTheme.accentGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: onUnload,
            child: const Text('Eject',
                style: TextStyle(
                    fontSize: 12,
                    color: PaperclipTheme.mutedDark)),
          ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatefulWidget {
  final ModelInfo model;
  final VoidCallback onLoad;
  final VoidCallback onUnload;
  const _ModelRow(
      {required this.model,
      required this.onLoad,
      required this.onUnload});

  @override
  State<_ModelRow> createState() => _ModelRowState();
}

class _ModelRowState extends State<_ModelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final isLoaded = m.isLoaded;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isLoaded
            ? PaperclipTheme.accentGreen.withOpacity(0.04)
            : _hovered
                ? PaperclipTheme.surfaceDark
                : Colors.transparent,
        child: Row(
          children: [
            // Icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isLoaded
                        ? PaperclipTheme.accentGreen
                        : PaperclipTheme.mutedFgDark)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLoaded
                    ? Icons.play_circle_filled
                    : Icons.smart_toy_outlined,
                color: isLoaded
                    ? PaperclipTheme.accentGreen
                    : PaperclipTheme.mutedFgDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Name + source
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(m.source,
                      style: const TextStyle(
                          color: PaperclipTheme.mutedFgDark,
                          fontSize: 11)),
                ],
              ),
            ),
            // Quant chip
            SizedBox(
              width: 80,
              child: _Chip(m.quantization,
                  color: PaperclipTheme.accentCyan),
            ),
            // Vision
            SizedBox(
              width: 60,
              child: m.supportsVision
                  ? const Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 14, color: PaperclipTheme.accentPurple),
                        SizedBox(width: 4),
                        Text('Yes', style: TextStyle(color: PaperclipTheme.accentPurple, fontSize: 12)),
                      ],
                    )
                  : const Text('-', style: TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 12)),
            ),
            // Size
            SizedBox(
              width: 70,
              child: m.sizeGb > 0
                  ? Text(
                      '${m.sizeGb.toStringAsFixed(1)} GB',
                      style: const TextStyle(
                          color: PaperclipTheme.mutedDark,
                          fontSize: 12))
                  : const SizedBox.shrink(),
            ),
            // Actions (shown on hover or when loaded)
            Container(
              width: 90,
              alignment: Alignment.centerRight,
              child: m.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: PaperclipTheme.accentCyan))
                  : (_hovered || isLoaded)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isLoaded)
                              _ActionBtn(
                                  icon: Icons.play_arrow,
                                  label: 'Load',
                                  color: PaperclipTheme.accentCyan,
                                  onTap: widget.onLoad)
                            else
                              _ActionBtn(
                                  icon: Icons.eject,
                                  label: 'Eject',
                                  color: PaperclipTheme.mutedDark,
                                  onTap: widget.onUnload),
                          ],
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Server Tab ───────────────────────────────────────────────────────────────

class _ServerTab extends ConsumerStatefulWidget {
  const _ServerTab();

  @override
  ConsumerState<_ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends ConsumerState<_ServerTab> {
  final _urlCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = ref.read(modelManagerProvider);
    _urlCtrl.text = s.serverUrl;
    _portCtrl.text = s.serverPort.toString();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelManagerProvider);
    final notifier = ref.read(modelManagerProvider.notifier);
    final isRunning = state.serverStatus == ServerStatus.running;
    final isStarting = state.serverStatus == ServerStatus.starting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PaperclipTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PaperclipTheme.borderDark),
            ),
            child: Row(
              children: [
                _StatusDot(
                    running: isRunning, starting: isStarting),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRunning
                            ? 'Server Running'
                            : isStarting
                                ? 'Starting…'
                                : 'Server Stopped',
                        style: TextStyle(
                            color: isRunning
                                ? PaperclipTheme.accentGreen
                                : isStarting
                                    ? PaperclipTheme.accentAmber
                                    : PaperclipTheme.mutedDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      if (isRunning)
                        Text(
                            '${state.serverUrl}:${state.serverPort}',
                            style: const TextStyle(
                                color: PaperclipTheme.mutedFgDark,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                    ],
                  ),
                ),
                if (!isRunning)
                  ElevatedButton(
                    onPressed:
                        isStarting ? null : notifier.startServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaperclipTheme.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                    ),
                    child: Text(
                        isStarting ? 'Starting…' : 'Start Server'),
                  )
                else
                  OutlinedButton(
                    onPressed: notifier.stopServer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PaperclipTheme.accentRed,
                      side: const BorderSide(
                          color: PaperclipTheme.accentRed),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                    ),
                    child: const Text('Stop'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('CONFIGURATION'),
          const SizedBox(height: 10),
          _CfgRow(
              label: 'Host URL',
              child: _inputField(
                  ctrl: _urlCtrl,
                  hint: 'http://127.0.0.1',
                  onSubmit: notifier.updateExternalServer)),
          const SizedBox(height: 8),
          _CfgRow(
              label: 'Port',
              child: SizedBox(
                  width: 120,
                  child: _inputField(
                      ctrl: _portCtrl,
                      hint: '1234',
                      onSubmit: (v) {
                        final p = int.tryParse(v);
                        if (p != null) notifier.setServerPort(p);
                      }))),
          const SizedBox(height: 24),
          _SectionLabel('MODEL FOR HOSTING'),
          const SizedBox(height: 10),
          if (state.downloadedModels.isEmpty)
            const Text('No downloaded models.',
                style: TextStyle(
                    color: PaperclipTheme.mutedFgDark, fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.downloadedModels.map((m) {
                final sel = state.selectedModelForHosting == m.path;
                return GestureDetector(
                  onTap: () => notifier.setHostingModel(m.path),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? PaperclipTheme.accentCyan.withOpacity(0.12)
                          : PaperclipTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: sel
                              ? PaperclipTheme.accentCyan
                              : PaperclipTheme.borderDark,
                          width: 1),
                    ),
                    child: Text(m.name,
                        style: TextStyle(
                            fontSize: 12,
                            color: sel
                                ? PaperclipTheme.accentCyan
                                : PaperclipTheme.mutedDark,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _inputField(
      {required TextEditingController ctrl,
      required String hint,
      required void Function(String) onSubmit}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(
          color: PaperclipTheme.foregroundDark, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: PaperclipTheme.mutedFgDark, fontSize: 13),
        filled: true,
        fillColor: PaperclipTheme.surfaceElevatedDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(
                color: PaperclipTheme.accentCyan, width: 1.5)),
      ),
      onSubmitted: onSubmit,
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool running;
  final bool starting;
  const _StatusDot({required this.running, required this.starting});

  @override
  Widget build(BuildContext context) {
    final color = running
        ? PaperclipTheme.accentGreen
        : starting
            ? PaperclipTheme.accentAmber
            : PaperclipTheme.mutedFgDark;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: running
            ? [
                BoxShadow(
                    color: color.withOpacity(0.6), blurRadius: 8)
              ]
            : null,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: PaperclipTheme.mutedFgDark,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2));
  }
}

class _CfgRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _CfgRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: PaperclipTheme.mutedDark,
                    fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

// ─── LM Studio Tab ─────────────────────────────────────────────────────────────

class _LmStudioTab extends ConsumerStatefulWidget {
  const _LmStudioTab();

  @override
  ConsumerState<_LmStudioTab> createState() => _LmStudioTabState();
}

class _LmStudioTabState extends ConsumerState<_LmStudioTab> {
  bool _isLoading = true;
  String? _error;
  List<ModelInfo> _models = [];

  @override
  void initState() {
    super.initState();
    _fetchLmStudioModels();
  }

  Future<void> _fetchLmStudioModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await apiDio.get(ApiConstants.modelsLmStudio);
      final list = List<Map<String, dynamic>>.from(res.data['models'] ?? []);
      setState(() {
        _models = list.map((m) => ModelInfo.fromJson(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load LM Studio models: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: PaperclipTheme.accentCyan));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: PaperclipTheme.accentRed),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: PaperclipTheme.mutedDark)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLmStudioModels,
              style: ElevatedButton.styleFrom(backgroundColor: PaperclipTheme.surfaceDark),
              child: const Text('Retry', style: TextStyle(color: PaperclipTheme.foregroundDark)),
            )
          ],
        ),
      );
    }

    if (_models.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 40, color: PaperclipTheme.mutedFgDark),
            SizedBox(height: 16),
            Text('No models found in LM Studio directory',
                style: TextStyle(color: PaperclipTheme.mutedDark)),
            SizedBox(height: 8),
            Text('Ensure models are downloaded via LM Studio to ~/.lmstudio/models',
                style: TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PaperclipTheme.borderDark, width: 1))),
          child: Row(
            children: [
              const Expanded(
                  child: Text('Model',
                      style: TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600))),
              SizedBox(
                  width: 80,
                  child: const Text('Quant',
                      style: TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600))),
              SizedBox(
                  width: 80,
                  child: const Text('Vision',
                      style: TextStyle(
                          fontSize: 11,
                          color: PaperclipTheme.mutedFgDark,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 90),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _models.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, color: PaperclipTheme.borderDark, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final m = _models[i];
              return _LmStudioModelRow(
                model: m,
                onLoad: () async {
                  await ref.read(modelManagerProvider.notifier).loadCustomModel(m.path!);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LmStudioModelRow extends ConsumerStatefulWidget {
  final ModelInfo model;
  final VoidCallback onLoad;
  const _LmStudioModelRow({required this.model, required this.onLoad});

  @override
  ConsumerState<_LmStudioModelRow> createState() => _LmStudioModelRowState();
}

class _LmStudioModelRowState extends ConsumerState<_LmStudioModelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    
    // Check if this model is currently loaded in the manager state
    final globalState = ref.watch(modelManagerProvider);
    final isLoaded = globalState.downloadedModels
        .where((g) => g.isLoaded && g.path == m.path)
        .isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isLoaded
            ? PaperclipTheme.accentGreen.withOpacity(0.04)
            : _hovered
                ? PaperclipTheme.surfaceDark
                : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isLoaded ? PaperclipTheme.accentGreen : PaperclipTheme.mutedFgDark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLoaded ? Icons.play_circle_filled : Icons.folder_shared_outlined,
                color: isLoaded ? PaperclipTheme.accentGreen : PaperclipTheme.mutedFgDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(m.id, style: const TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: _Chip(m.quantization, color: PaperclipTheme.accentCyan),
            ),
            SizedBox(
              width: 80,
              child: m.supportsVision
                  ? const Row(
                      children: [
                        Icon(Icons.remove_red_eye, size: 14, color: PaperclipTheme.accentPurple),
                        SizedBox(width: 4),
                        Text('Yes', style: TextStyle(color: PaperclipTheme.accentPurple, fontSize: 12)),
                      ],
                    )
                  : const Text('-', style: TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 12)),
            ),
            Container(
              width: 90,
              alignment: Alignment.centerRight,
              child: _hovered || isLoaded
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isLoaded)
                          _ActionBtn(
                              icon: Icons.play_arrow,
                              label: 'Load',
                              color: PaperclipTheme.accentCyan,
                              onTap: widget.onLoad)
                        else
                          _ActionBtn(
                              icon: Icons.eject,
                              label: 'Eject',
                              color: PaperclipTheme.mutedDark,
                              onTap: () {
                                ref.read(modelManagerProvider.notifier).unloadModel(m.id);
                              }),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Tab ─────────────────────────────────────────────────────────────

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelManagerProvider);
    final notifier = ref.read(modelManagerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('INFERENCE PARAMETERS'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ParamCard(
                  label: 'Context (n_ctx)',
                  value: state.nCtx.toString(),
                  onChanged: (v) {
                    final i = int.tryParse(v);
                    if (i != null) notifier.setNCtx(i);
                  }),
              _ParamCard(
                  label: 'GPU Layers',
                  hint: '-1 = all',
                  value: state.nGpuLayers.toString(),
                  onChanged: (v) {
                    final i = int.tryParse(v);
                    if (i != null) notifier.setNGpuLayers(i);
                  }),
              _ParamCard(
                  label: 'Threads',
                  hint: '0 = auto',
                  value: state.nThreads.toString(),
                  onChanged: (v) {
                    final i = int.tryParse(v);
                    if (i != null) notifier.setNThreads(i);
                  }),
              _ParamCard(
                  label: 'Batch Size',
                  value: state.nBatch.toString(),
                  onChanged: (v) {
                    final i = int.tryParse(v);
                    if (i != null) notifier.setNBatch(i);
                  }),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamCard extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final void Function(String) onChanged;
  const _ParamCard(
      {required this.label,
      required this.value,
      this.hint,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaperclipTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PaperclipTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: PaperclipTheme.mutedFgDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          if (hint != null)
            Text(hint!,
                style: const TextStyle(
                    color: PaperclipTheme.mutedFgDark, fontSize: 10)),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: value),
            style: const TextStyle(
                color: PaperclipTheme.foregroundDark,
                fontSize: 13,
                fontFamily: 'monospace'),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: PaperclipTheme.surfaceElevatedDark,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(
                      color: PaperclipTheme.accentCyan, width: 1.5)),
            ),
            onSubmitted: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── HuggingFace Search Dialog ────────────────────────────────────────────────

class _HFSearchDialog extends StatefulWidget {
  const _HFSearchDialog();

  @override
  State<_HFSearchDialog> createState() => _HFSearchDialogState();
}

class _HFSearchDialogState extends State<_HFSearchDialog> {
  final _ctrl = TextEditingController();
  final _dio = hf_dio.Dio();
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  bool _loadingDetail = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('gguf llm');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    _dio.close();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(v.isEmpty ? 'gguf llm' : v);
    });
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get(
        'https://huggingface.co/api/models',
        queryParameters: {
          'search': query,
          'filter': 'gguf',
          'sort': 'downloads',
          'direction': -1,
          'limit': 30,
        },
        options: hf_dio.Options(
            headers: {'Accept': 'application/json'}),
      );
      if (!mounted) return;
      final data = res.data as List;
      setState(() {
        _results = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed. Check connection.';
        _loading = false;
      });
    }
  }

  Future<void> _selectModel(Map<String, dynamic> model) async {
    setState(() {
      _selected = model;
      _loadingDetail = true;
    });
    try {
      final id = model['id'] as String? ?? '';
      final res = await _dio.get(
          'https://huggingface.co/api/models/$id');
      if (!mounted) return;
      setState(() {
        _selected =
            Map<String, dynamic>.from(res.data as Map);
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 860,
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: PaperclipTheme.sidebarDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PaperclipTheme.borderDark),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(
                    height: 1, color: PaperclipTheme.borderDark),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      color: PaperclipTheme.sidebarDark,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: PaperclipTheme.accentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.search,
                color: PaperclipTheme.accentCyan, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Browse HuggingFace',
              style: TextStyle(
                  color: PaperclipTheme.foregroundDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              autofocus: true,
              style: const TextStyle(
                  color: PaperclipTheme.foregroundDark, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'Search models (mistral, llama, gemma, phi…)',
                hintStyle: const TextStyle(
                    color: PaperclipTheme.mutedFgDark,
                    fontSize: 13),
                filled: true,
                fillColor: PaperclipTheme.surfaceElevatedDark,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search,
                    color: PaperclipTheme.mutedFgDark, size: 16),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: PaperclipTheme.accentCyan)))
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close,
                color: PaperclipTheme.mutedFgDark, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        Container(
          width: 300,
          decoration: const BoxDecoration(
              border: Border(
                  right: BorderSide(
                      color: PaperclipTheme.borderDark, width: 1))),
          child: _buildList(),
        ),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildList() {
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!,
                  style: const TextStyle(
                      color: PaperclipTheme.accentRed,
                      fontSize: 13))));
    }
    if (_loading && _results.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(
              color: PaperclipTheme.accentCyan, strokeWidth: 2));
    }
    if (_results.isEmpty) {
      return const Center(
          child: Text('No results',
              style: TextStyle(
                  color: PaperclipTheme.mutedFgDark)));
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final m = _results[i];
        final id = m['id'] as String? ?? '';
        final dl = m['downloads'] as int? ?? 0;
        final likes = m['likes'] as int? ?? 0;
        final isSelected = _selected?['id'] == id;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _selectModel(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: isSelected
                  ? PaperclipTheme.accentCyan.withOpacity(0.1)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: PaperclipTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSelected
                              ? PaperclipTheme.accentCyan.withOpacity(0.4)
                              : PaperclipTheme.borderDark),
                    ),
                    child: Icon(Icons.smart_toy_outlined,
                        size: 15,
                        color: isSelected
                            ? PaperclipTheme.accentCyan
                            : PaperclipTheme.mutedFgDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          id.contains('/')
                              ? id.split('/').last
                              : id,
                          style: TextStyle(
                              color: isSelected
                                  ? PaperclipTheme.accentCyan
                                  : PaperclipTheme.foregroundDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          id.contains('/')
                              ? id.split('/').first
                              : 'HuggingFace',
                          style: const TextStyle(
                              color: PaperclipTheme.mutedFgDark,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Row(children: [
                        const Icon(Icons.download_outlined,
                            size: 11,
                            color: PaperclipTheme.mutedFgDark),
                        const SizedBox(width: 2),
                        Text(_fmt(dl),
                            style: const TextStyle(
                                color: PaperclipTheme.mutedFgDark,
                                fontSize: 10)),
                      ]),
                      Row(children: [
                        const Icon(Icons.favorite_outline,
                            size: 11,
                            color: PaperclipTheme.mutedFgDark),
                        const SizedBox(width: 2),
                        Text(_fmt(likes),
                            style: const TextStyle(
                                color: PaperclipTheme.mutedFgDark,
                                fontSize: 10)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetail() {
    if (_selected == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_ios,
                color: PaperclipTheme.mutedFgDark, size: 24),
            SizedBox(height: 12),
            Text('Select a model to view details',
                style: TextStyle(
                    color: PaperclipTheme.mutedFgDark,
                    fontSize: 13)),
          ],
        ),
      );
    }
    if (_loadingDetail) {
      return const Center(
          child: CircularProgressIndicator(
              color: PaperclipTheme.accentCyan, strokeWidth: 2));
    }

    final m = _selected!;
    final id = m['id'] as String? ?? '';
    final dl = m['downloads'] as int? ?? 0;
    final likes = m['likes'] as int? ?? 0;
    final tags = List<String>.from(m['tags'] ?? []);
    final lastMod = m['lastModified'] as String? ?? '';
    final siblings = (m['siblings'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .where((s) => (s['rfilename'] as String? ?? '')
            .toLowerCase()
            .endsWith('.gguf'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Model header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id.contains('/')
                          ? id.split('/').last
                          : id,
                      style: const TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text:
                              'https://huggingface.co/$id'));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                              content: Text(
                                  'URL copied to clipboard'),
                              behavior:
                                  SnackBarBehavior.floating));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PaperclipTheme.surfaceDark,
                        borderRadius:
                            BorderRadius.circular(7),
                        border: Border.all(
                            color: PaperclipTheme.borderDark),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 13,
                              color: PaperclipTheme.mutedFgDark),
                          SizedBox(width: 5),
                          Text('Copy URL',
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      PaperclipTheme.mutedFgDark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                id.contains('/')
                    ? id.split('/').first
                    : 'HuggingFace',
                style: const TextStyle(
                    color: PaperclipTheme.accentCyan, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _StatPill(
                    icon: Icons.download_outlined,
                    label: _fmt(dl)),
                const SizedBox(width: 8),
                _StatPill(
                    icon: Icons.favorite_outline,
                    label: _fmt(likes)),
                if (lastMod.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _StatPill(
                      icon: Icons.schedule,
                      label: _fmtDate(lastMod)),
                ],
              ]),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .take(8)
                      .map((t) => _Chip(t))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: PaperclipTheme.borderDark),
        // GGUF files list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (siblings.isNotEmpty) ...[
                const Row(children: [
                  Icon(Icons.download_outlined,
                      size: 14,
                      color: PaperclipTheme.mutedDark),
                  SizedBox(width: 6),
                  Text('GGUF Files',
                      style: TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                ...siblings.map((f) =>
                    _GGUFRow(modelId: id, file: f)),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
        // CTA
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              color: PaperclipTheme.sidebarDark,
              border: Border(
                  top: BorderSide(
                      color: PaperclipTheme.borderDark, width: 1))),
          child: Consumer(builder: (ctx, ref, _) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Add to Cyborg',
                    style: TextStyle(
                        fontWeight: FontWeight.w600)),
                onPressed: () {
                  ref
                      .read(modelManagerProvider.notifier)
                      .downloadModel(id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(
                    content: Text(
                        'Queued: ${id.split('/').last}'),
                    backgroundColor:
                        PaperclipTheme.surfaceDark,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaperclipTheme.accentCyan,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d).inDays;
      if (diff == 0) return 'Today';
      if (diff < 7) return '$diff days ago';
      if (diff < 30) return '${diff ~/ 7}w ago';
      return '${diff ~/ 30}mo ago';
    } catch (_) {
      return '';
    }
  }
}

class _GGUFRow extends StatefulWidget {
  final String modelId;
  final Map<String, dynamic> file;
  const _GGUFRow({required this.modelId, required this.file});

  @override
  State<_GGUFRow> createState() => _GGUFRowState();
}

class _GGUFRowState extends State<_GGUFRow> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.file['rfilename'] as String? ?? '';
    final size = widget.file['size'] as int? ?? 0;
    final sizeStr =
        size > 0 ? '${(size / 1e9).toStringAsFixed(2)} GB' : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _h
              ? PaperclipTheme.surfaceDark
              : PaperclipTheme.surfaceElevatedDark.withOpacity(0.4),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: PaperclipTheme.borderDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: PaperclipTheme.foregroundDark,
                          fontSize: 12,
                          fontFamily: 'monospace')),
                  if (sizeStr.isNotEmpty)
                    Text(sizeStr,
                        style: const TextStyle(
                            color: PaperclipTheme.mutedFgDark,
                            fontSize: 11)),
                ],
              ),
            ),
            Consumer(builder: (ctx, ref, _) {
              return GestureDetector(
                onTap: () {
                  ref
                      .read(modelManagerProvider.notifier)
                      .downloadModel(widget.modelId);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(const SnackBar(
                    content: Text('Download queued'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PaperclipTheme.accentCyan,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Download',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Shared tiny widgets ──────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? PaperclipTheme.mutedFgDark;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.2), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: PaperclipTheme.mutedFgDark),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: PaperclipTheme.mutedFgDark, fontSize: 12)),
      ],
    );
  }
}
