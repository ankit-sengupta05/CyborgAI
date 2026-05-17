import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/backend_service.dart';

import '../../../core/providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _progressCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  double _progress = 0.0;
  double _displayProgress = 0.0; // smoothly animated
  String _statusText = 'Initializing Cyborg…';
  int _statusUpdateCount = 0;
  String _currentDetails = '';
  bool _isError = false;
  final List<_LogLine> _logLines = [];

  StreamSubscription<BackendProgress>? _sub;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _progressCtrl.addListener(() {
      setState(() => _displayProgress = _progressCtrl.value);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ── Boot sequence ─────────────────────────────────────────────────────────
  Future<void> _boot() async {
    final svc = ref.read(backendServiceProvider);

    _sub = svc.progressStream.listen(_onProgress);

    try {
      await svc.initialize();
      await ref.read(inferenceBackendProvider).initialize();
    } catch (e) {
      _setError('Backend setup failed: $e');
      return;
    }

    // Auth check
    _addStep('Checking authentication…', 0.92);
    await Future.delayed(const Duration(milliseconds: 300));

    _addStep('Loading workspace…', 0.96);
    await Future.delayed(const Duration(milliseconds: 400));

    _addStep('All systems ready ✓', 1.0);
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    context.go(user != null ? '/chat' : '/auth/login');
  }

  void _onProgress(BackendProgress evt) {
    if (!mounted) return;
    setState(() {
      if (_statusText != evt.message) {
        _statusText = evt.message;
        _statusUpdateCount++;
      }
      _currentDetails = evt.details;
      _isError = evt.status == BackendStatus.error;
      _progress = evt.progress;
      _logLines.add(_LogLine(evt.message, _isError));
      if (_logLines.length > 6) _logLines.removeAt(0);
    });
    _progressCtrl.animateTo(evt.progress,
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  void _addStep(String msg, double prog) {
    if (!mounted) return;
    setState(() {
      if (_statusText != msg) {
        _statusText = msg;
        _statusUpdateCount++;
      }
      _progress = prog;
      _logLines.add(_LogLine(msg, false));
      if (_logLines.length > 6) _logLines.removeAt(0);
    });
    _progressCtrl.animateTo(prog,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      if (_statusText != msg) {
        _statusText = msg;
        _statusUpdateCount++;
      }
      _isError = true;
      _logLines.add(_LogLine(msg, true));
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = _isError ? const Color(0xFFff4455) : AppColors.accent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(children: [
          // ── Radial glow background ────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 340 * _pulseAnim.value,
                height: 340 * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: _Logo(accent: accent),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Title
                    Text('CYBORG',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 10,
                          shadows: [
                            Shadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 20)
                          ],
                        )),
                    const SizedBox(height: 6),
                    const Text('Local-First AGI Platform',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 2.5,
                        )),

                    const SizedBox(height: 52),

                    // ── Progress bar ──────────────────────────────────
                    _ProgressBar(
                      progress: _displayProgress,
                      accent: accent,
                      isError: _isError,
                    ),
                    const SizedBox(height: 14),

                    // Current status
                    Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _statusText,
                            key: ValueKey('$_statusText-$_statusUpdateCount'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isError
                                  ? const Color(0xFFff4455)
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (_currentDetails.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _currentDetails,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Log lines ────────────────────────────────────
                    _LogPanel(lines: _logLines, accent: accent),

                    const SizedBox(height: 16),

                    // Percentage
                    Text(
                      '${(_displayProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Version watermark ─────────────────────────────────────────
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Text('v1.0.0 — local inference engine',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final Color accent;
  const _Logo({required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: 4),
          ],
        ),
        child: Icon(Icons.memory, color: accent, size: 52),
      );
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final bool isError;
  const _ProgressBar(
      {required this.progress, required this.accent, required this.isError});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 5,
              child: Stack(children: [
                // Background
                Container(
                  color: AppColors.surfaceVariant,
                ),
                // Fill
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accent.withValues(alpha: 0.7),
                        accent,
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                // Shimmer sweep
                if (!isError && progress < 1.0)
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.5),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      );
}

class _LogLine {
  final String text;
  final bool isError;
  _LogLine(this.text, this.isError);
}

class _LogPanel extends StatelessWidget {
  final List<_LogLine> lines;
  final Color accent;
  const _LogPanel({required this.lines, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox(height: 72);
    return Container(
      width: double.infinity,
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.12), width: 1),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: lines.length,
        itemBuilder: (_, i) {
          final line = lines[lines.length - 1 - i];
          return Text(
            '${i == 0 ? '▶' : '·'} ${line.text}',
            style: TextStyle(
              color: line.isError
                  ? const Color(0xFFff4455)
                  : i == 0
                      ? AppColors.textPrimary.withValues(alpha: 0.9)
                      : AppColors.textSecondary.withValues(alpha: 0.45),
              fontSize: 10.5,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          );
        },
      ),
    );
  }
}
