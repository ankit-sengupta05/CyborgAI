import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backend_service.dart';
import '../services/lightrt_service.dart';
import '../services/inference_backend.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../services/api_service.dart';
import '../../features/mirofish/providers/app_provider.dart' as mf;
import 'package:hive_flutter/hive_flutter.dart';

// ── MiroFish (Persistence) ───────────────────────────────────────────────────
final miroFishProvider = Provider<mf.AppProvider>((ref) {
  final provider = mf.AppProvider()..useCyborgBackend();
  ref.onDispose(provider.dispose);
  return provider;
});

// ── Theme ─────────────────────────────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _load();
  }
  void _load() {
    final box = Hive.box('cyborg_cache');
    final isDark = box.get('isDarkMode', defaultValue: true);
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    Hive.box('cyborg_cache').put('isDarkMode', state == ThemeMode.dark);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());

// ── Voice Response Toggle ───────────────────────────────────────────────────
final voiceEnabledProvider = StateProvider<bool>((ref) => false);
final handsFreeEnabledProvider = StateProvider<bool>((ref) => false);

// ── Platform-aware inference backend ─────────────────────────────────────────
//
// Windows → BackendService  (Python/FastAPI + llama-cpp-python/CUDA)
// Android → AndroidInferenceService (LightRT FFI + cross-device offload)
//
// Both implement [InferenceBackend] so the UI is platform-agnostic.
final inferenceBackendProvider = Provider<InferenceBackend>((ref) {
  if (Platform.isWindows) {
    // Windows: reuse the existing BackendService (it already implements
    // full Python backend lifecycle). Wrap it in an adapter below.
    final svc = ref.read(backendServiceProvider);
    ref.onDispose(svc.dispose);
    return _WindowsBackendAdapter(svc);
  } else {
    // Android: LightRT on-device inference with cross-device fallback
    final svc = AndroidInferenceService();
    ref.onDispose(svc.dispose);
    return svc;
  }
});

// ── Windows-only BackendService (Python lifecycle) ─────────────────────────
// Kept separate so the SplashScreen can still watch BackendProgress directly.
final backendStatusProvider = StreamProvider<BackendProgress>((ref) {
  if (!Platform.isWindows) {
    // On Android, map AndroidInferenceService progress to BackendProgress
    final backend = ref.read(inferenceBackendProvider);
    return backend.progressStream.map((p) => BackendProgress(
          _mapInferenceStatus(p.status),
          p.message,
          p.progress,
        ));
  }

  final svc = ref.read(backendServiceProvider);
  return (() async* {
    yield svc.currentProgress;
    yield* svc.progressStream;
  })();
});

BackendStatus _mapInferenceStatus(InferenceStatus s) => switch (s) {
      InferenceStatus.stopped => BackendStatus.stopped,
      InferenceStatus.initializing => BackendStatus.checkingEnv,
      InferenceStatus.loadingModel => BackendStatus.starting,
      InferenceStatus.ready => BackendStatus.running,
      InferenceStatus.inferring => BackendStatus.running,
      InferenceStatus.error => BackendStatus.error,
    };

// ── Firebase auth ─────────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// ── UI state ─────────────────────────────────────────────────────────────────
final activeNavIndexProvider = StateProvider<int>((ref) => 0);
final globalLoadingProvider = StateProvider<bool>((ref) => false);
final globalErrorProvider = StateProvider<String?>((ref) => null);

// ── Windows backend adapter ───────────────────────────────────────────────────
/// Wraps BackendService so it satisfies the InferenceBackend interface.
/// Windows-only — [AndroidInferenceService] is used on Android.
class _WindowsBackendAdapter implements InferenceBackend {
  final BackendService _svc;
  _WindowsBackendAdapter(this._svc);

  @override
  Stream<InferenceProgress> get progressStream => _svc.progressStream.map(
        (p) => InferenceProgress(
            _mapInferenceStatus2(p.status), p.message, p.progress),
      );

  @override
  InferenceStatus get status => _mapInferenceStatus2(_svc.status);

  @override
  bool get isReady => _svc.status == BackendStatus.running;

  @override
  Future<void> initialize() => _svc.initialize();

  @override
  Future<void> loadModel(String modelPath) async {
    // Windows backend uses apiDio to hit /models/load_custom
    await apiDio.post(ApiConstants.modelsLoadCustom, data: {'path': modelPath});
  }

  @override
  Stream<String> complete({
    required String prompt,
    String? modelPath,
    double temperature = 0.7,
    int maxTokens = 2048,
    double topP = 0.9,
  }) async* {
    // Delegates to the Python /v1/chat/completions SSE endpoint
    // (implemented in chat feature layer)
    throw UnimplementedError(
        'Use the chat API client to call the Python backend directly.');
  }

  @override
  Future<void> stop() => _svc.stop();

  @override
  void dispose() => _svc.dispose();

  InferenceStatus _mapInferenceStatus2(BackendStatus s) => switch (s) {
        BackendStatus.stopped => InferenceStatus.stopped,
        BackendStatus.checkingEnv => InferenceStatus.initializing,
        BackendStatus.detectingCuda => InferenceStatus.initializing,
        BackendStatus.creatingVenv => InferenceStatus.initializing,
        BackendStatus.installingTorch => InferenceStatus.initializing,
        BackendStatus.installingDeps => InferenceStatus.initializing,
        BackendStatus.starting => InferenceStatus.loadingModel,
        BackendStatus.running => InferenceStatus.ready,
        BackendStatus.error => InferenceStatus.error,
      };
}
