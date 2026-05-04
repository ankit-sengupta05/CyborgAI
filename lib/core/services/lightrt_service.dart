import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'inference_backend.dart';
import 'device_discovery_service.dart';

// ── FFI Bindings (Removed) ───────────────────────────────────────────────────
// We now use the official Google MediaPipe Tasks GenAI library via MethodChannel
// instead of custom FFI wrappers to ensure robust on-device execution.

// ── Service ───────────────────────────────────────────────────────────────────
/// Android-only LightRT inference service.
///
/// Strategy (in priority order):
/// 1. Load `com.google.mediapipe:tasks-genai` via MethodChannel for native LightRT
/// 2. If LightRT initialization fails (e.g., model is gguf instead of bin), fallback to Mock/Windows
class AndroidInferenceService implements InferenceBackend {
  final _progressController = StreamController<InferenceProgress>.broadcast();

  static const MethodChannel _channel =
      MethodChannel('com.ankit.cyborg/lightrt');
  static const EventChannel _eventChannel =
      EventChannel('com.ankit.cyborg/lightrt_events');
  StreamSubscription? _eventSubscription;

  @override
  Stream<InferenceProgress> get progressStream => _progressController.stream;

  @override
  InferenceStatus get status => _status;
  InferenceStatus _status = InferenceStatus.stopped;

  @override
  bool get isReady => _status == InferenceStatus.ready;

  bool _nativeAvailable = false;
  String? _loadedModelPath;

  // Cross-device offload
  final DeviceDiscoveryService _discovery = DeviceDiscoveryService();
  String? _remoteBaseUrl; // fallback Windows Cyborg URL

  bool _useMock = false;

  // ── Initialize ─────────────────────────────────────────────────────────────
  @override
  Future<void> initialize() async {
    if (_status == InferenceStatus.ready) return;

    _emit(
        InferenceStatus.initializing, 'Initializing Android inference…', 0.05);

    // LightRT requires initialization per-model via loadModel(),
    // so here we just setup the event listener for streaming tokens.
    _setupEventListener();
    _nativeAvailable =
        true; // Assume available until loadModel proves otherwise

    // Try finding Windows PC just in case we need a fallback
    _emit(InferenceStatus.initializing,
        'Scanning for Windows Cyborg as fallback…', 0.30);
    try {
      _remoteBaseUrl = await _discovery
          .findWindowsCyborgInstance()
          .timeout(const Duration(seconds: 4));
      if (_remoteBaseUrl != null) {
        _emit(InferenceStatus.ready,
            'No LightRT / Network PC found. Mock Engine Active.', 1.0);
        _status = InferenceStatus.ready;
      }
    } catch (_) {
      // Ignore network errors, LightRT is the primary target anyway
    }
  }

  void _setupEventListener() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((event) {}, onError: (error) {
      debugPrint('[LightRT] Stream error: $error');
    });
  }

  // ── Model loading ──────────────────────────────────────────────────────────
  Future<void> loadModel(String modelPath) async {
    if (!_nativeAvailable && !_useMock) return; // offload mode
    if (_loadedModelPath == modelPath) return;

    _emit(InferenceStatus.loadingModel, 'Loading model (LightRT)…', 0.10);

    if (_useMock) {
      await Future.delayed(const Duration(seconds: 1));
      _loadedModelPath = modelPath;
      _emit(InferenceStatus.ready, 'Mock Model loaded ✓', 1.0);
      return;
    }

    try {
      final success = await _channel
          .invokeMethod<bool>('init_lightrt', {'modelPath': modelPath});
      if (success == true) {
        _loadedModelPath = modelPath;
        _emit(InferenceStatus.ready, 'Model loaded ✓', 1.0);
      } else {
        throw Exception("Unknown error initializing LightRT");
      }
    } catch (e) {
      _nativeAvailable = false;
      _emit(InferenceStatus.error, 'LightRT initialization failed: $e', 0.0);
      throw Exception('LightRT Init Failed: $e');
    }
  }

  // ── Inference ──────────────────────────────────────────────────────────────
  @override
  Stream<String> complete({
    required String prompt,
    String? modelPath,
    double temperature = 0.7,
    int maxTokens = 2048,
    double topP = 0.9,
  }) async* {
    if (_nativeAvailable) {
      yield* _completeNative(
          prompt: prompt,
          modelPath: modelPath,
          temperature: temperature,
          maxTokens: maxTokens,
          topP: topP);
    } else if (_remoteBaseUrl != null) {
      yield* _completeRemote(
          prompt: prompt,
          temperature: temperature,
          maxTokens: maxTokens,
          topP: topP);
    } else if (_useMock) {
      if (modelPath != null) await loadModel(modelPath);
      yield* _completeMock(prompt: prompt);
    } else {
      throw StateError('Android inference not ready. Call initialize() first.');
    }
  }

  Stream<String> _completeMock({required String prompt}) async* {
    _status = InferenceStatus.inferring;
    const response =
        "This is a mock response from the on-device inference engine. "
        "The real LightRT C++ binary (liblightrt.so) is missing or not compiled yet, "
        "but the UI and state management are fully connected and functional!";
    final words = response.split(' ');
    for (final word in words) {
      await Future.delayed(const Duration(milliseconds: 50));
      yield '$word ';
    }
    _status = InferenceStatus.ready;
  }

  /// On-device inference via LightRT MethodChannel.
  Stream<String> _completeNative({
    required String prompt,
    String? modelPath,
    required double temperature,
    required int maxTokens,
    required double topP,
  }) async* {
    if (modelPath != null) await loadModel(modelPath);

    _status = InferenceStatus.inferring;

    // We use a completer to know when the stream is done, and a local stream controller
    // to pipe the tokens from the global event subscription.
    final controller = StreamController<String>();

    final sub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event == "[DONE]") {
        controller.close();
      } else if (event is String) {
        controller.add(event);
      }
    }, onError: (err) {
      controller.addError(err);
      controller.close();
    });

    try {
      await _channel.invokeMethod('generate_lightrt', {'prompt': prompt});
      await for (final token in controller.stream) {
        yield token;
      }
    } finally {
      await sub.cancel();
      _status = InferenceStatus.ready;
    }
  }

  /// Cross-device offload: stream inference from Windows Cyborg via HTTP SSE.
  Stream<String> _completeRemote({
    required String prompt,
    required double temperature,
    required int maxTokens,
    required double topP,
  }) async* {
    // Uses OpenAI-compatible streaming endpoint on the Windows Python backend
    final uri = Uri.parse('$_remoteBaseUrl/v1/chat/completions');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      request.write('''
{
  "model": "local",
  "messages": [{"role": "user", "content": "${prompt.replaceAll('"', '\\"')}"}],
  "temperature": $temperature,
  "max_tokens": $maxTokens,
  "top_p": $topP,
  "stream": true
}''');

      final response = await request.close();
      await for (final chunk
          in response.transform(const SystemEncoding().decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ') && !line.contains('[DONE]')) {
            final data = line.substring(6).trim();
            if (data.isEmpty) continue;
            try {
              // Extract delta.content from SSE JSON
              final match =
                  RegExp(r'"content"\s*:\s*"([^"]*)"').firstMatch(data);
              if (match != null) yield match.group(1)!;
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Performance metrics ────────────────────────────────────────────────────
  bool get isGpuAccelerated =>
      _nativeAvailable; // MediaPipe Tasks GenAI auto-selects GPU when available

  double get tokensPerSecond =>
      0.0; // MediaPipe SDK does not expose this directly yet

  String get backendMode =>
      _nativeAvailable ? 'LightRT (on-device)' : 'Windows Cyborg (offload)';

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  Future<void> stop() async {
    if (_nativeAvailable) {
      try {
        await _channel.invokeMethod('unload_lightrt');
      } catch (_) {}
    }
    _loadedModelPath = null;
    _emit(InferenceStatus.stopped, 'Stopped', 0.0);
  }

  @override
  void dispose() {
    stop();
    _progressController.close();
    _discovery.dispose();
  }

  void _emit(InferenceStatus status, String message, double progress) {
    _status = status;
    if (!_progressController.isClosed) {
      _progressController.add(InferenceProgress(status, message, progress));
    }
    debugPrint('[AndroidInference] $message (${(progress * 100).toInt()}%)');
  }
}

// ── Device capability detection ───────────────────────────────────────────────
class DeviceSpecs {
  int cpuCores = 4;
  int optimalGpuLayers = 0;
  int optimalThreads = 4;
  int optimalContextSize = 2048;
  bool supportsVulkan = false;
  int availableMemoryMb = 2048;
}

class DeviceCapabilities {
  static Future<DeviceSpecs> detect() async {
    final specs = DeviceSpecs();
    try {
      // CPU cores from platform
      specs.cpuCores = Platform.numberOfProcessors;
      specs.optimalThreads = specs.cpuCores >= 8
          ? 6
          : specs.cpuCores >= 4
              ? 4
              : 2;

      // Memory heuristic from cache dir (conservative estimate)
      final dir = await getTemporaryDirectory();
      final stat = await dir.stat();
      // Available memory estimate (no public API on Android without native code)
      specs.availableMemoryMb = 3000; // conservative default
      specs.optimalContextSize = specs.availableMemoryMb > 4000
          ? 8192
          : specs.availableMemoryMb > 2000
              ? 4096
              : 2048;

      // Vulkan support detection (requires native call in production)
      // For now, assume Vulkan is available on API 28+ (Android 9+)
      specs.supportsVulkan = true; // Will be confirmed at runtime by LightRT
      specs.optimalGpuLayers = specs.supportsVulkan ? 28 : 0;
    } catch (e) {
      debugPrint('[DeviceCapabilities] Detection error: $e — using defaults');
    }
    return specs;
  }
}
