import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/backend_service.dart';
import '../providers/app_state.dart';
import 'package:provider/provider.dart' as legacy_provider;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo / wordmark ────────────────────────────────────────
              Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Icon(Icons.push_pin,
                        size: 16, color: theme.colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'paperclip',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Open-source orchestration for zero-human companies',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),

              Consumer(builder: (context, ref, _) {
                final progress = ref.watch(backendServiceProvider);
                
                return Container(
                  margin: const EdgeInsets.only(top: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              progress.message,
                              style: theme.textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${(progress.progress * 100).toInt()}%',
                              style: theme.textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress.progress),
                      if (progress.details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          progress.details,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10, color: theme.hintColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
