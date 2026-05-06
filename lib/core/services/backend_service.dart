import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../constants/api_constants.dart';
import 'device_discovery_service.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final backendServiceProvider = Provider<BackendService>((ref) {
  final svc = BackendService();
  ref.onDispose(svc.dispose);
  return svc;
});

// ── Status enum ───────────────────────────────────────────────────────────────
enum BackendStatus {
  stopped,
  checkingEnv,
  detectingCuda,
  creatingVenv,
  installingTorch,
  installingDeps,
  starting,
  running,
  error,
}

// ── Progress event ────────────────────────────────────────────────────────────
class BackendProgress {
  final BackendStatus status;
  final String message;
  final String details;
  final double progress; // 0.0 – 1.0
  final bool cudaActive;
  final bool llmReady;
  final bool voiceReady;

  const BackendProgress(this.status, this.message, this.progress,
      {this.details = '',
      this.cudaActive = false,
      this.llmReady = false,
      this.voiceReady = false});
}

// ── Service ───────────────────────────────────────────────────────────────────
class BackendService {
  Process? _backendProcess;
  BackendStatus _status = BackendStatus.stopped;

  final _progressController = StreamController<BackendProgress>.broadcast();
  BackendProgress _currentProgress = const BackendProgress(
      BackendStatus.stopped, 'Offline', 0.0,
      cudaActive: false, llmReady: false, voiceReady: false);

  Stream<BackendProgress> get progressStream => _progressController.stream;
  BackendProgress get currentProgress => _currentProgress;
  BackendStatus get status => _status;

  final Dio _dio = Dio();
  final _discoveryResponder = CyborgDiscoveryResponder();

  // ── Public entry point ─────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_status == BackendStatus.running) return;

    // Backend is Windows-only (local Python process).
    // On Android/iOS the app connects to a remote/cloud backend instead.
    if (!Platform.isWindows) {
      _emit(BackendStatus.running, 'Remote backend mode (non-Windows platform)',
          1.0);
      return;
    }

    _emit(BackendStatus.checkingEnv, 'Checking backend services…', 0.03);

    // In debug mode, always kill existing backend to ensure code changes are applied
    if (kDebugMode && Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'python.exe', '/T']);
      } catch (_) {}
    } else if (await _isBackendAlive()) {
      _emit(BackendStatus.running, 'Backend already running √', 1.0);
      return;
    }

    final backendDir = _backendDir();
    if (!Directory(backendDir).existsSync()) {
      _emit(
          BackendStatus.error, 'Backend directory not found: $backendDir', 0.0);
      throw Exception('Backend directory missing');
    }

    // Always run setup script. UV verifies/installs requirements in milliseconds.
    await _runSetupScript(backendDir);
    _emit(BackendStatus.checkingEnv, 'Environment ready ✓ — starting server…',
        0.55);

    await _startServer(backendDir);
  }

  // ── Python discovery ───────────────────────────────────────────────────────
  /// Returns the first working Python 3.8+ executable found on this machine.
  Future<String?> _findSystemPython() async {
    final candidates = <String>[
      'python3.12',
      'python3.11',
      'python3.10',
      'py', // Windows Python Launcher (will try to pick 3.12)
      'python',
      'python3',
      'python3.13',
    ];

    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    final localApp = Platform.environment['LOCALAPPDATA'] ?? '';

    final absolutePaths = <String>[
      r'C:\Windows\py.exe',
      p.join(localApp, 'Programs', 'Python', 'Python312', 'python.exe'),
      p.join(localApp, 'Programs', 'Python', 'Python311', 'python.exe'),
      p.join(localApp, 'Programs', 'Python', 'Python310', 'python.exe'),
      p.join(localApp, 'Programs', 'Python', 'Python313', 'python.exe'),
      r'C:\Python312\python.exe',
      r'C:\Python311\python.exe',
      r'C:\Python310\python.exe',
      r'C:\Python313\python.exe',
      p.join(home, 'AppData', 'Local', 'Programs', 'Python', 'Python312',
          'python.exe'),
      p.join(home, 'AppData', 'Local', 'Programs', 'Python', 'Python313',
          'python.exe'),
    ];

    for (final candidate in [...candidates, ...absolutePaths]) {
      try {
        final r = await Process.run(candidate, ['--version']);
        if (r.exitCode == 0) {
          final version = (r.stdout.toString() + r.stderr.toString()).trim();
          // Use regex to extract major.minor — avoids substring false-matches
          // (e.g. '3.1' matching '3.10', '3.13', etc.)
          final m = RegExp(r'Python (\d+)\.(\d+)').firstMatch(version);
          if (m != null) {
            final major = int.parse(m.group(1)!);
            final minor = int.parse(m.group(2)!);
            if (major > 3 || (major == 3 && minor >= 8)) {
              debugPrint(
                  '[BackendService] Found Python: $candidate → $version');
              return candidate;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ── First-boot: run setup_env.py ──────────────────────────────────────────
  Future<void> _runSetupScript(String backendDir) async {
    _emit(BackendStatus.detectingCuda, 'Detecting GPU / CUDA version…', 0.05);

    final python = await _findSystemPython();
    if (python == null) {
      _emit(BackendStatus.error,
          'Python 3.8+ not found. Please install Python from python.org', 0.0);
      throw Exception('Python not found');
    }

    final setupScript = p.join(backendDir, 'setup_env.py');
    if (!File(setupScript).existsSync()) {
      _emit(BackendStatus.error, 'setup_env.py missing from backend dir', 0.0);
      throw Exception('setup_env.py not found');
    }

    debugPrint('[BackendService] Running setup_env.py with: $python');
    _emit(BackendStatus.creatingVenv, 'First launch — preparing environment…',
        0.08);

    final process = await Process.start(
      python,
      [setupScript],
      workingDirectory: backendDir,
      environment: {
        ...Platform.environment,
        'PYTHONUNBUFFERED': '1',
        'PYTHONDONTWRITEBYTECODE': '1',
      },
    );

    // Parse JSON lines from setup_env.py stdout
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(_parseSetupLine);

    // Forward stderr to debug log
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) => debugPrint('[setup_env] $line'));

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      _emit(BackendStatus.error,
          'Environment setup failed (exit $exitCode). Check logs.', 0.0);
      throw Exception('setup_env.py failed with exit code $exitCode');
    }
  }

  /// Parses a JSON line from setup_env.py and emits a [BackendProgress].
  void _parseSetupLine(String line) {
    line = line.trim();
    if (line.isEmpty) return;
    debugPrint('[setup_env] $line');

    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final status = json['status'] as String? ?? 'progress';
      final message = json['message'] as String? ?? '';
      final progress = (json['progress'] as num?)?.toDouble() ?? 0.0;
      final cuda = json['cuda_active'] as bool? ?? false;

      final backendStatus = switch (status) {
        'done' => BackendStatus.installingDeps,
        'error' => BackendStatus.error,
        _ => _statusFromProgress(progress),
      };

      _emit(backendStatus, message, progress, cudaActive: cuda);
    } catch (_) {
      // Non-JSON line (debug text) — ignore silently
    }
  }

  BackendStatus _statusFromProgress(double p) {
    if (p < 0.10) return BackendStatus.detectingCuda;
    if (p < 0.20) return BackendStatus.creatingVenv;
    if (p < 0.46) return BackendStatus.installingTorch;
    return BackendStatus.installingDeps;
  }

  // ── Server launch ──────────────────────────────────────────────────────────
  Future<void> _startServer(String backendDir) async {
    _emit(BackendStatus.starting, 'Starting Cyborg backend server…', 0.60);

    final python = _venvPython(backendDir);
    if (!File(python).existsSync()) {
      _emit(
          BackendStatus.error,
          'venv Python not found at: $python\nRun the app again to retry setup.',
          0.0);
      throw Exception('venv python missing');
    }

    _backendProcess = await Process.start(
      python,
      ['main.py'],
      workingDirectory: backendDir,
      environment: {
        ...Platform.environment,
        'PYTHONUNBUFFERED': '1',
      },
    );

    // Watch stdout for startup confirmation
    _backendProcess!.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      debugPrint('[Backend] $line');
      if (_isServerReady(line)) {
        _emit(BackendStatus.running, 'Backend online ✓', 1.0);
        _status = BackendStatus.running;
      }
    });

    _backendProcess!.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      debugPrint('[Backend ERR] $line');
      if (_isServerReady(line)) {
        _emit(BackendStatus.running, 'Backend online ✓', 1.0);
        _status = BackendStatus.running;
      }
    });

    await _pollUntilAlive();
  }

  bool _isServerReady(String line) =>
      line.contains('Uvicorn running') ||
      line.contains('Application startup complete') ||
      line.contains('started server process') ||
      line.contains('Started server process');

  Future<void> _pollUntilAlive() async {
    _emit(BackendStatus.starting, 'Waiting for backend to accept connections…',
        0.65);
    for (var i = 0; i < 600; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (await _isBackendAlive()) {
        final ready = _currentProgress.llmReady && _currentProgress.voiceReady;
        if (ready) {
          _emit(BackendStatus.running, 'Backend online ✓', 1.0);
          _status = BackendStatus.running;
          // Start UDP discovery responder with LAN IP so remote devices can connect
          _getLocalIp().then((lanIp) {
            final discoveryUrl = lanIp != null
                ? 'http://$lanIp:8765'
                : ApiConstants.baseUrl.replaceAll('/api/v1/', '');

            _discoveryResponder.start(apiBaseUrl: discoveryUrl).then((_) {
              debugPrint(
                  '[BackendService] Discovery responder active on UDP:17173 (announced: $discoveryUrl)');
            });
          });
          return;
        } else {
          // Still loading models
          String msg = 'Initializing components...';
          String detailText = _currentProgress.details;

          if (!_currentProgress.llmReady && !_currentProgress.voiceReady) {
            msg = 'Loading LLM & Voice...';
          } else if (!_currentProgress.llmReady) {
            msg = 'Initializing LLM...';
          } else if (!_currentProgress.voiceReady) {
            msg = 'Initializing Voice...';
          }

          _emit(BackendStatus.starting, msg, 0.80 + (i / 600) * 0.15,
              details: detailText);
        }
      } else {
        final prog = 0.65 + (i / 600) * (0.75 - 0.65);
        _emit(BackendStatus.starting, 'Starting up… (${i + 1}s)', prog);
      }
    }
    _emit(
        BackendStatus.error, 'Backend timed out — check logs/backend.log', 0.0);
    _status = BackendStatus.error;
  }

  // ── Path helpers ───────────────────────────────────────────────────────────
  String _backendDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isWindows) {
      // In development, prioritize the source assets/backend so .venv persists
      final devBackend = p.normalize(p.join(
        exeDir,
        '..',
        '..',
        '..',
        '..',
        '..',
        'assets',
        'backend',
      ));
      if (Directory(devBackend).existsSync()) {
        return devBackend;
      }
      return p.join(exeDir, 'backend');
    }
    // Android/Linux Dev mode fallback
    return p.normalize(p.join(
      exeDir,
      '..',
      '..',
      '..',
      '..',
      '..',
      'assets',
      'backend',
    ));
  }

  bool _venvExists(String backendDir) =>
      File(_venvPython(backendDir)).existsSync();

  String _venvPython(String backendDir) => Platform.isWindows
      ? p.join(backendDir, '.venv', 'Scripts', 'python.exe')
      : p.join(backendDir, '.venv', 'bin', 'python');

  // ── Health check ───────────────────────────────────────────────────────────
  Future<bool> _isBackendAlive() async {
    try {
      final resp = await _dio.get(
        '${ApiConstants.baseUrl}health',
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
      if (resp.statusCode == 200) {
        final data = resp.data as Map<String, dynamic>;
        final cuda = data['cuda_active'] as bool? ?? false;
        final llm = data['llm_ready'] as bool? ?? false;
        final voice = data['voice_ready'] as bool? ?? false;

        final detailsMap = data['details'] as Map<String, dynamic>? ?? {};
        String detailStr = '';
        if (detailsMap.isNotEmpty) {
          final llmD = detailsMap['llm'] ?? '';
          final voiceD = detailsMap['voice'] ?? '';
          if (!llm && !voice) {
            detailStr = 'LLM: $llmD | Voice: $voiceD';
          } else if (!llm) {
            detailStr = 'LLM: $llmD';
          } else if (!voice) {
            detailStr = 'Voice: $voiceD';
          }
        }

        // Update progress state with latest health info
        if (_currentProgress.cudaActive != cuda ||
            _currentProgress.llmReady != llm ||
            _currentProgress.voiceReady != voice ||
            _currentProgress.details != detailStr) {
          _emit(_status, _currentProgress.message, _currentProgress.progress,
              details: detailStr,
              cudaActive: cuda,
              llmReady: llm,
              voiceReady: voice);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Emit helper ────────────────────────────────────────────────────────────
  void _emit(BackendStatus status, String message, double progress,
      {String? details, bool? cudaActive, bool? llmReady, bool? voiceReady}) {
    _status = status;
    final det = details ?? _currentProgress.details;
    final cuda = cudaActive ?? _currentProgress.cudaActive;
    final llm = llmReady ?? _currentProgress.llmReady;
    final v = voiceReady ?? _currentProgress.voiceReady;

    _currentProgress = BackendProgress(status, message, progress,
        details: det, cudaActive: cuda, llmReady: llm, voiceReady: v);

    if (!_progressController.isClosed) {
      _progressController.add(_currentProgress);
    }
    debugPrint(
        '[BackendService] $message ($det) (${(progress * 100).toStringAsFixed(0)}%) [CUDA: $cuda, LLM: $llm, Voice: $v]');
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  Future<void> stop() async {
    _backendProcess?.kill();
    _backendProcess = null;
    _emit(BackendStatus.stopped, 'Backend stopped', 0.0);
  }

  void dispose() {
    stop();
    _discoveryResponder.stop();
    _progressController.close();
  }
}
