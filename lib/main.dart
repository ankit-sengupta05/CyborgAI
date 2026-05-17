import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'theme/paperclip_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/agents_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/other_screens.dart';
import 'screens/onboarding_screen.dart';
import 'screens/workspaces_screen.dart';
import 'widgets/sidebar.dart';
import 'features/chat/screens/chat_screen.dart';
import 'core/services/backend_service.dart';
import 'features/knowledge_graph/screens/graph_screen.dart';
import 'features/vault/screens/vault_screen.dart';
import 'features/ingest/screens/ingest_screen.dart';
import 'features/world_monitor/screens/world_monitor_screen.dart';
import 'features/mirofish/screens/mirofish_screen.dart';
import 'features/gsd/screens/gsd_screen.dart';
import 'features/education/screens/education_home_screen.dart';
import 'features/health/screens/health_home_screen.dart';
import 'features/codeflow/screens/codeflow_screen.dart';
import 'features/github/screens/github_screen.dart';
import 'features/skills/screens/skills_screen.dart';
import 'features/device_manager/screens/device_manager_screen.dart';
import 'features/model_manager/screens/model_manager_screen.dart';
import 'features/voice_assistant/screens/voice_assistant_screen.dart';
import 'features/voice_agent/screens/voice_agent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local storage in a OneDrive-safe location
  final appDir = await getApplicationSupportDirectory();
  await Hive.initFlutter(appDir.path);
  await Hive.openBox('cyborg_cache');
  await Hive.openBox('cyborg_settings');
  await Hive.openBox('cyborg_projects');

  final container = ProviderContainer();
  final backendSvc = container.read(backendServiceProvider.notifier);
  // Start backend in background so UI doesn't hang
  unawaited(backendSvc.initialize().catchError((e, stack) {
    debugPrint('[Bootstrap Error] $e');
    debugPrint(stack.toString());
  }));

  final appState = AppState();
  await appState.init();

  // Listen for backend success to auto-connect to main app
  container.listen(backendServiceProvider, (prev, next) {
    if (next.status == BackendStatus.running && !appState.connected) {
      appState.connect();
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: ChangeNotifierProvider.value(
        value: appState,
        child: const PaperclipApp(),
      ),
    ),
  );
}

class PaperclipApp extends StatelessWidget {
  const PaperclipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ExcludeSemantics(
      child: MaterialApp(
        title: 'Paperclip',
        debugShowCheckedModeBanner: false,
        theme: PaperclipTheme.light(),
        darkTheme: PaperclipTheme.dark(),
        themeMode: state.themeMode,
        home: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell();

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  AppRoute _currentRoute = AppRoute.dashboard;
  bool _sidebarOpen = true;

  void _navigate(AppRoute route) {
    setState(() => _currentRoute = route);
  }

  Widget _buildScreen() => switch (_currentRoute) {
        AppRoute.dashboard => const DashboardScreen(),
        AppRoute.issues => const IssuesScreen(),
        AppRoute.agents => const AgentsScreen(),
        AppRoute.goals => const GoalsScreen(),
        AppRoute.projects => const ProjectsScreen(),
        AppRoute.routines => const RoutinesScreen(),
        AppRoute.approvals => const ApprovalsScreen(),
        AppRoute.costs => const CostsScreen(),
        AppRoute.activity => const ActivityScreen(),
        AppRoute.org => const OrgChartScreen(),
        AppRoute.workspaces => const WorkspacesScreen(),
        AppRoute.settings => const SettingsScreen(),
        AppRoute.lmStudio => const LmStudioScreen(),
        AppRoute.graph => const KnowledgeGraphScreen(),
        AppRoute.chat => const ChatScreen(),
        AppRoute.vault => const VaultScreen(),
        AppRoute.ingest => const IngestScreen(),
        AppRoute.worldMonitor => const WorldMonitorScreen(),
        AppRoute.mirofish => const MiroFishScreen(),
        AppRoute.gsd => const GSDScreen(),
        AppRoute.education => const EducationHomeScreen(),
        AppRoute.health => const HealthHomeScreen(),
        AppRoute.codeFlow => const CodeFlowScreen(),
        AppRoute.github => const GitHubScreen(),
        AppRoute.skills => const SkillsScreen(),
        AppRoute.deviceManager => const DeviceManagerScreen(),
        AppRoute.modelsLibrary => const ModelManagerScreen(),
        AppRoute.voiceAssistant => const VoiceAssistantScreen(),
        AppRoute.voiceCallAgent => const VoiceAgentScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final backend = ref.watch(backendServiceProvider);
    final theme = Theme.of(context);

    // Show onboarding only if backend isn't ready
    if (backend.status != BackendStatus.running) {
      return const OnboardingScreen();
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return ExcludeSemantics(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        // ── Mobile: drawer-based sidebar ─────────────────────────────────
        drawer: isMobile
            ? Drawer(
                width: PaperclipTheme.sidebarWidth,
                backgroundColor: theme.scaffoldBackgroundColor,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                child: PcSidebar(
                  currentRoute: _currentRoute,
                  onNavigate: (r) {
                    Navigator.pop(context);
                    _navigate(r);
                  },
                ),
              )
            : null,
        body: Column(
          children: [
            // ── Top breadcrumb bar ──────────────────────────────────────────
            Builder(
              builder: (innerContext) => _BreadcrumbBar(
                route: _currentRoute,
                isMobile: isMobile,
                onMenuTap: () => Scaffold.of(innerContext).openDrawer(),
                onToggleSidebar: () =>
                    setState(() => _sidebarOpen = !_sidebarOpen),
              ),
            ),
  
            Expanded(
              child: Row(
                children: [
                  // ── Desktop sidebar ───────────────────────────────────────
                  if (!isMobile && _sidebarOpen)
                    PcSidebar(
                      currentRoute: _currentRoute,
                      onNavigate: _navigate,
                    ),
  
                  // ── Main content ──────────────────────────────────────────
                  Expanded(
                    child: _buildScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
        // ── Mobile bottom nav ────────────────────────────────────────────────
        bottomNavigationBar: isMobile
            ? _MobileBottomNav(
                current: _currentRoute,
                onNavigate: _navigate,
              )
            : null,
      ),
    );
  }
}

// ── Breadcrumb / top bar ────────────────────────────────────────────────────
class _BreadcrumbBar extends ConsumerWidget {
  final AppRoute route;
  final bool isMobile;
  final VoidCallback onMenuTap;
  final VoidCallback onToggleSidebar;

  const _BreadcrumbBar({
    super.key,
    required this.route,
    required this.isMobile,
    required this.onMenuTap,
    required this.onToggleSidebar,
  });

  static const _routeLabels = {
    AppRoute.dashboard: 'Dashboard',
    AppRoute.issues: 'Issues',
    AppRoute.agents: 'Agents',
    AppRoute.goals: 'Goals',
    AppRoute.projects: 'Projects',
    AppRoute.routines: 'Routines',
    AppRoute.approvals: 'Approvals',
    AppRoute.costs: 'Costs',
    AppRoute.activity: 'Activity',
    AppRoute.org: 'Org Chart',
    AppRoute.workspaces: 'Workspaces',
    AppRoute.settings: 'Settings',
    AppRoute.lmStudio: 'LM Studio',
    AppRoute.graph: 'Knowledge Graph',
    AppRoute.chat: 'AGI Chat',
    AppRoute.vault: 'Vault',
    AppRoute.ingest: 'Ingest',
    AppRoute.worldMonitor: 'World Monitor',
    AppRoute.mirofish: 'MiroFish',
    AppRoute.gsd: 'GSD Engine',
    AppRoute.education: 'Education',
    AppRoute.health: 'Health',
    AppRoute.codeFlow: 'CodeFlow',
    AppRoute.github: 'GitHub Sync',
    AppRoute.skills: 'Skills',
    AppRoute.deviceManager: 'Devices',
    AppRoute.modelsLibrary: 'Models Library',
    AppRoute.voiceCallAgent: 'Call Agent',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? PaperclipTheme.backgroundDark : PaperclipTheme.surfaceLight,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Menu / sidebar toggle
          _TopBarIconBtn(
            icon: isMobile ? Icons.menu_rounded : Icons.menu_rounded,
            tooltip: isMobile ? 'Menu' : 'Toggle sidebar',
            onTap: isMobile ? onMenuTap : onToggleSidebar,
          ),
          const SizedBox(width: 8),

          // Company prefix pill
          if (state.selectedCompany != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: PaperclipTheme.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: PaperclipTheme.accentGreen.withValues(alpha: 0.3)),
              ),
              child: Text(
                state.selectedCompany!.issuePrefix,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PaperclipTheme.accentGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded,
                  size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
          ],

          Text(
            _routeLabels[route] ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),

          const Spacer(),

          // LM Studio indicator
          if (state.lmStudioConfig.enabled) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.lmStudioConnected
                    ? PaperclipTheme.accentGreen
                    : PaperclipTheme.mutedFgDark,
                boxShadow: state.lmStudioConnected
                    ? [BoxShadow(color: PaperclipTheme.accentGreen.withValues(alpha: 0.5), blurRadius: 4)]
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LM',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: state.lmStudioConnected
                      ? PaperclipTheme.accentGreen
                      : theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            ),
            const SizedBox(width: 10),
          ],

          // Backend GPU/CPU badge
          _BackendStatusBadge(
            cudaActive: ref.watch(backendServiceProvider).cudaActive,
          ),
        ],
      ),
    );
  }
}

class _BackendStatusBadge extends StatelessWidget {
  final bool cudaActive;
  const _BackendStatusBadge({required this.cudaActive});

  @override
  Widget build(BuildContext context) {
    final color = cudaActive ? PaperclipTheme.accentGreen : PaperclipTheme.accentCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, spreadRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 3)],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            cudaActive ? 'GPU' : 'CPU',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Topbar icon button helper ──────────────────────────────────────────────
class _TopBarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopBarIconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_TopBarIconBtn> createState() => _TopBarIconBtnState();
}

class _TopBarIconBtnState extends State<_TopBarIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered ? theme.colorScheme.onSurface.withValues(alpha: 0.07) : Colors.transparent,
              borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
            ),
            child: Icon(widget.icon, size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: _hovered ? 0.8 : 0.5)),
          ),
        ),
      ),
    );
  }
}

// ── Mobile bottom nav ────────────────────────────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  final AppRoute current;
  final void Function(AppRoute) onNavigate;
  const _MobileBottomNav({required this.current, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (AppRoute.dashboard, Icons.grid_view_rounded, 'Home'),
      (AppRoute.issues, Icons.circle_outlined, 'Issues'),
      (AppRoute.chat, Icons.chat_bubble_rounded, 'Chat'),
      (AppRoute.agents, Icons.smart_toy_rounded, 'Agents'),
      (AppRoute.settings, Icons.tune_rounded, 'Settings'),
    ];

    return Container(
      height: 60 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: PaperclipTheme.surfaceDark,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: items.map((item) {
          final selected = current == item.$1;
          return Expanded(
            child: InkWell(
              onTap: () => onNavigate(item.$1),
              splashColor: PaperclipTheme.accentGreen.withValues(alpha: 0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$2, size: 20,
                      color: selected
                          ? PaperclipTheme.accentGreen
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                  const SizedBox(height: 3),
                  Text(item.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? PaperclipTheme.accentGreen
                            : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Placeholder screen for unimplemented pages ──────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction,
              size: 32, color: theme.colorScheme.onSurface.withAlpha(80)),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Coming soon', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
