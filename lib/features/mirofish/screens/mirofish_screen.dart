/// MiroFish — Swarm Intelligence Simulation Engine
/// Wraps the full mirofish app inside Cyborg's shell.
/// LLM backend auto-wires to Cyborg's inference engine (port 8765).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import '../../../core/providers/app_providers.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';
import 'graph_build/graph_build_screen.dart';
import 'env_setup/env_setup_screen.dart';
import 'simulation/simulation_screen.dart';
import 'report/report_screen.dart';
import 'interaction/interaction_screen.dart';

/// Entry point used by Cyborg's router — wraps mirofish in a Provider scope.
/// Uses a global provider from [app_providers.dart] to persist state across tabs.
class MiroFishScreen extends ConsumerWidget {
  const MiroFishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfProvider = ref.watch(miroFishProvider);

    // Ensure we are using the Cyborg backend when running in-app
    mfProvider.useCyborgBackend();

    return provider.ChangeNotifierProvider.value(
      value: mfProvider,
      child: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final step = context.watch<AppProvider>().step;
    switch (step) {
      case AppStep.home:        return const HomeScreen();
      case AppStep.graphBuild:  return const GraphBuildScreen();
      case AppStep.envSetup:    return const EnvSetupScreen();
      case AppStep.simulation:  return const SimulationScreen();
      case AppStep.report:      return const ReportScreen();
      case AppStep.interaction: return const InteractionScreen();
    }
  }
}
