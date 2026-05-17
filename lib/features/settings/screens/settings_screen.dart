import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/app_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  
  final _twUserCtrl = TextEditingController();
  final _twPassCtrl = TextEditingController();
  final _igUserCtrl = TextEditingController();
  final _igPassCtrl = TextEditingController();
  final _fbUserCtrl = TextEditingController();
  final _fbPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Wait for context to mount
    Future.microtask(_loadCredentials);
  }

  Future<void> _loadCredentials() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    try {
      final creds = await appState.api.getCredentials();
      if (mounted) {
        setState(() {
          _twUserCtrl.text = creds['twitter_username'] ?? '';
          _twPassCtrl.text = creds['twitter_password'] ?? '';
          _igUserCtrl.text = creds['instagram_username'] ?? '';
          _igPassCtrl.text = creds['instagram_password'] ?? '';
          _fbUserCtrl.text = creds['facebook_username'] ?? '';
          _fbPassCtrl.text = creds['facebook_password'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCredentials() async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    try {
      await appState.api.saveCredentials({
        'twitter_username': _twUserCtrl.text,
        'twitter_password': _twPassCtrl.text,
        'instagram_username': _igUserCtrl.text,
        'instagram_password': _igPassCtrl.text,
        'facebook_username': _fbUserCtrl.text,
        'facebook_password': _fbPassCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credentials saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving credentials: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionHeader(title: 'Appearance'),
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
                      activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
                      activeThumbColor: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // ── Social Media Automation Credentials ──
                const _SectionHeader(title: 'Agentic UI Credentials'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Provide credentials to allow the AI to autonomously manage your social media accounts via a headless browser.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        _buildCredField('Twitter/X Username', _twUserCtrl),
                        _buildCredField('Twitter/X Password', _twPassCtrl, obscure: true),
                        const Divider(height: 32),
                        _buildCredField('Instagram Username', _igUserCtrl),
                        _buildCredField('Instagram Password', _igPassCtrl, obscure: true),
                        const Divider(height: 32),
                        _buildCredField('Facebook Username', _fbUserCtrl),
                        _buildCredField('Facebook Password', _fbPassCtrl, obscure: true),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveCredentials,
                            icon: _saving 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving...' : 'Save Credentials'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                const _SectionHeader(title: 'About'),
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

  Widget _buildCredField(String label, TextEditingController ctrl, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
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
