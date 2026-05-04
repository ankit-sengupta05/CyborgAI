import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/knowledge_graph/screens/graph_screen.dart';
import '../../features/model_manager/screens/model_manager_screen.dart';
import '../../features/gsd/screens/gsd_screen.dart';
import '../../features/github/screens/github_screen.dart';
import '../../features/world_monitor/screens/world_monitor_screen.dart';
import '../../features/codeflow/screens/codeflow_screen.dart';
import '../../features/device_manager/screens/device_manager_screen.dart';
import '../../features/vault/screens/vault_screen.dart';
import '../../features/ingest/screens/ingest_screen.dart';
import '../../features/mirofish/screens/mirofish_screen.dart';
// Gemma 4 Health & Education tracks
import '../../features/health/screens/health_home_screen.dart';
import '../../features/health/screens/xray_analyzer_screen.dart';
import '../../features/education/screens/education_home_screen.dart';
import '../../features/education/screens/homework_scanner_screen.dart';
import '../../features/education/screens/quiz_player_screen.dart';
import '../widgets/app_shell.dart';

import 'package:hive/hive.dart';

bool get devModeOfflineBypass =>
    Hive.box('cyborg_cache').get('offline_bypass', defaultValue: false);
set devModeOfflineBypass(bool val) =>
    Hive.box('cyborg_cache').put('offline_bypass', val);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isAuth = user != null || devModeOfflineBypass;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (isSplash) return null;
      if (!isAuth && !isAuthRoute) return '/auth/login';
      if (isAuth && isAuthRoute) return '/chat';
      return null;
    },
    refreshListenable: AuthStateChangeNotifier(),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(
              path: '/chat/:id',
              builder: (_, s) => ChatScreen(sessionId: s.pathParameters['id'])),
          GoRoute(
              path: '/graph', builder: (_, __) => const KnowledgeGraphScreen()),
          GoRoute(path: '/vault', builder: (_, __) => const VaultScreen()),
          GoRoute(
              path: '/models', builder: (_, __) => const ModelManagerScreen()),
          GoRoute(path: '/gsd', builder: (_, __) => const GSDScreen()),
          GoRoute(
              path: '/codeflow', builder: (_, __) => const CodeFlowScreen()),
          GoRoute(
              path: '/monitor', builder: (_, __) => const WorldMonitorScreen()),
          GoRoute(
              path: '/mirofish', builder: (_, __) => const MiroFishScreen()),
          GoRoute(
              path: '/devices',
              builder: (_, __) => const DeviceManagerScreen()),
          GoRoute(path: '/github', builder: (_, __) => const GitHubScreen()),
          GoRoute(path: '/ingest', builder: (_, __) => const IngestScreen()),
          // ── Gemma 4: Health Track ────────────────────────────────────────
          GoRoute(
              path: '/health', builder: (_, __) => const HealthHomeScreen()),
          GoRoute(
              path: '/health/xray',
              builder: (_, __) => const XRayAnalyzerScreen()),
          // ── Gemma 4: Education Track ─────────────────────────────────────
          GoRoute(
              path: '/education',
              builder: (_, __) => const EducationHomeScreen()),
          GoRoute(
              path: '/education/homework',
              builder: (_, __) => const HomeworkScannerScreen()),
          GoRoute(
              path: '/education/quiz',
              builder: (_, __) => const QuizPlayerScreen()),
        ],
      ),
    ],
  );
});

class AuthStateChangeNotifier extends ChangeNotifier {
  AuthStateChangeNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}
