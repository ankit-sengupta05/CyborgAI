import 'dart:async';

/// Platform-agnostic inference backend interface.
/// Both [WindowsBackendService] (Python/FastAPI) and [AndroidInferenceService]
/// (LightRT FFI) implement this contract so the UI never needs to know which is running.
abstract class InferenceBackend {
  /// Stream of [InferenceProgress] events during initialization.
  Stream<InferenceProgress> get progressStream;

  /// Current backend status.
  InferenceStatus get status;

  /// true once the backend is ready to accept inference requests.
  bool get isReady;

  /// Initialize and start the backend (idempotent — safe to call multiple times).
  Future<void> initialize();

  /// Explicitly load a model into memory.
  Future<void> loadModel(String modelPath);

  /// Stream token-by-token completions for [prompt].
  Stream<String> complete({
    required String prompt,
    String? modelPath,
    double temperature = 0.7,
    int maxTokens = 2048,
    double topP = 0.9,
  });

  /// Unload model & release resources.
  Future<void> stop();

  void dispose();
}

// ── Status enum ───────────────────────────────────────────────────────────────
enum InferenceStatus {
  stopped,
  initializing,
  loadingModel,
  ready,
  inferring,
  error,
}

// ── Progress event ────────────────────────────────────────────────────────────
class InferenceProgress {
  final InferenceStatus status;
  final String message;
  final double progress; // 0.0 – 1.0

  const InferenceProgress(this.status, this.message, this.progress);
}
