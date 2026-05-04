import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart' as p;
import 'firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/backend_service.dart';
import 'core/providers/app_providers.dart';
import 'features/world_monitor/services/dashboard_provider.dart';
import 'features/world_monitor/services/data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local storage
  final appDir = await getApplicationSupportDirectory();
  Hive.init(appDir.path);
  await Hive.openBox('cyborg_cache');
  await Hive.openBox('cyborg_settings');
  await Hive.openBox('cyborg_projects');

  runApp(
    p.MultiProvider(
      providers: [
        p.ChangeNotifierProvider(create: (_) => DashboardProvider()),
        p.ChangeNotifierProvider(create: (_) => DataService()),
      ],
      child: const ProviderScope(
        child: CyborgApp(),
      ),
    ),
  );
}

class CyborgApp extends ConsumerStatefulWidget {
  const CyborgApp({super.key});

  @override
  ConsumerState<CyborgApp> createState() => _CyborgAppState();
}

class _CyborgAppState extends ConsumerState<CyborgApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Cyborg AI OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final data = MediaQuery.of(context);
        // Base width for desktop is 1200, for mobile is 400
        final isDesktop = data.size.width > 800;
        final baseWidth = isDesktop ? 1200.0 : 400.0;
        // Calculate a uniform scale factor clamped between 0.85 and 1.25
        final scale = (data.size.width / baseWidth).clamp(0.85, 1.25);

        return ExcludeSemantics(
          child: MediaQuery(
            data: data.copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}
