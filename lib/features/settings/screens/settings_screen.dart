import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Appearance'),
          Card(
            child: ListTile(
              leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                  color: AppColors.accent),
              title: const Text('Dark Mode'),
              subtitle: Text(isDark
                  ? 'Professional dark theme enabled'
                  : 'Clean light theme enabled'),
              trailing: Switch(
                value: isDark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                activeColor: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'About'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.textSecondary),
                  title: Text('Cyborg AI OS'),
                  subtitle: Text('Version 1.2.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.security, color: AppColors.textSecondary),
                  title: Text('Privacy & Security'),
                  subtitle: Text('Local-first inference active'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      );
}
