import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/paperclip_theme.dart';
import '../widgets/shared_widgets.dart';

// ── Settings Screen ────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  bool _saving = false;

  final _twUserCtrl = TextEditingController();
  final _twPassCtrl = TextEditingController();
  final _igUserCtrl = TextEditingController();
  final _igPassCtrl = TextEditingController();
  final _fbUserCtrl = TextEditingController();
  final _fbPassCtrl = TextEditingController();
  bool _loadingCreds = true;
  bool _savingCreds = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
        text: context.read<AppState>().serverUrl);
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
          _loadingCreds = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCreds = false);
    }
  }

  Future<void> _saveCredentials() async {
    setState(() => _savingCreds = true);
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
      if (mounted) setState(() => _savingCreds = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _twUserCtrl.dispose();
    _twPassCtrl.dispose();
    _igUserCtrl.dispose();
    _igPassCtrl.dispose();
    _fbUserCtrl.dispose();
    _fbPassCtrl.dispose();
    super.dispose();
  }

  Widget _buildCredField(String label, TextEditingController ctrl, ThemeData theme, {bool obscure = false}) {
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
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: PaperclipTheme.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.tune_rounded, size: 18, color: PaperclipTheme.accentGreen),
            ),
            const SizedBox(width: 12),
            Text('Settings', style: theme.textTheme.headlineMedium),
          ]),
          const SizedBox(height: 28),

          // ── Server ─────────────────────────────────────────────────────────
          PcSection(
            title: 'Server Connection',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(labelText: 'Paperclip Server URL'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saving ? null : () async {
                          setState(() => _saving = true);
                          await state.setServerUrl(_urlCtrl.text.trim());
                          if (mounted) setState(() => _saving = false);
                        },
                        child: _saving
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Connect'),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    PcConnectionBadge(
                      connected: state.connected,
                      label: state.connected
                          ? 'Connected to ${state.serverUrl}'
                          : state.connectionError ?? 'Not connected',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Theme ─────────────────────────────────────────────────────────
          PcSection(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text('Theme', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 14), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 14), label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.system,
                          icon: Icon(Icons.auto_mode_rounded, size: 14), label: Text('System')),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (s) => state.setThemeMode(s.first),
                  ),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Social Media Agentic UI Credentials ─────────────────────────
          PcSection(
            title: 'Agentic UI Credentials',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingCreds 
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Provide credentials to allow the AI to autonomously manage your social media accounts via a headless browser.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 16),
                        _buildCredField('Twitter/X Username', _twUserCtrl, theme),
                        _buildCredField('Twitter/X Password', _twPassCtrl, theme, obscure: true),
                        const Divider(height: 32),
                        _buildCredField('Instagram Username', _igUserCtrl, theme),
                        _buildCredField('Instagram Password', _igPassCtrl, theme, obscure: true),
                        const Divider(height: 32),
                        _buildCredField('Facebook Username', _fbUserCtrl, theme),
                        _buildCredField('Facebook Password', _fbPassCtrl, theme, obscure: true),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _savingCreds ? null : _saveCredentials,
                            icon: _savingCreds 
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save, size: 18),
                            label: Text(_savingCreds ? 'Saving...' : 'Save Credentials'),
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── About ─────────────────────────────────────────────────────────
          PcSection(
            title: 'About',
            children: [
              _InfoRow(label: 'App',     value: 'Cyborg AGI'),
              _InfoRow(label: 'Version', value: '1.0.0'),
              _InfoRow(label: 'Backend', value: 'Paperclip Server (Node.js)'),
              _InfoRow(label: 'License', value: 'MIT © 2026 Paperclip'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── LM Studio Screen ───────────────────────────────────────────────────────
class LmStudioScreen extends StatefulWidget {
  const LmStudioScreen({super.key});

  @override
  State<LmStudioScreen> createState() => _LmStudioScreenState();
}

class _LmStudioScreenState extends State<LmStudioScreen> {
  late TextEditingController _urlCtrl;
  String? _selectedModel;
  bool _testing = false;
  bool _chatLoading = false;
  final List<Map<String, String>> _messages = [];
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _urlCtrl = TextEditingController(text: state.lmStudioConfig.baseUrl);
    _selectedModel = state.lmStudioConfig.modelId;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final state = context.read<AppState>();
    await state.setLmStudioConfig(LmStudioConfig(
      baseUrl: _urlCtrl.text.trim(),
      modelId: _selectedModel,
      enabled: true,
    ));
    if (mounted) setState(() => _testing = false);
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _selectedModel == null) return;
    _chatCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _chatLoading = true;
    });
    _scroll();

    try {
      final state = context.read<AppState>();
      final result = await state.lmStudio.chat(
        modelId: _selectedModel!,
        messages: _messages,
      );
      final reply = (result['choices'] as List).first['message']['content'] as String;
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _chatLoading = false;
        });
        _scroll();
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'system', 'content': 'Error: ${e.message}'});
          _chatLoading = false;
        });
      }
    }
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final config = state.lmStudioConfig;

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(children: [
            const Icon(Icons.computer, size: 16),
            const SizedBox(width: 8),
            Text('LM Studio — Local LLM', style: theme.textTheme.titleMedium),
            const Spacer(),
            PcConnectionBadge(
                connected: state.lmStudioConnected,
                label: state.lmStudioConnected ? 'Connected' : 'Disconnected'),
          ]),
        ),

        Expanded(
          child: Row(
            children: [
              // ── Config panel ─────────────────────────────────────────────
              Container(
                width: 280,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: theme.dividerColor)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connection', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'LM Studio URL',
                          hintText: 'http://localhost:1234',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _testing ? null : _testConnection,
                          child: _testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('Test & Connect'),
                        ),
                      ),

                      if (state.lmStudioModels.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Model', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedModel,
                          hint: const Text('Select model'),
                          items: state.lmStudioModels
                              .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(m.displayName,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedModel = v);
                            if (v != null) {
                              state.setLmStudioConfig(LmStudioConfig(
                                baseUrl: config.baseUrl,
                                modelId: v,
                                enabled: config.enabled,
                              ));
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: theme.colorScheme.secondary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('About LM Studio',
                                style: theme.textTheme.labelMedium),
                            const SizedBox(height: 6),
                            Text(
                              'LM Studio lets you run LLMs locally. Start LM Studio, load a model, and enable the local server on port 1234.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () {},
                              child: Text('lmstudio.ai',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Chat panel ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  children: [
                    // Messages
                    Expanded(
                      child: !state.lmStudioConnected
                          ? const PcEmptyState(
                              icon: Icons.computer,
                              title: 'LM Studio not connected',
                              subtitle:
                                  'Enter your LM Studio URL and click Connect',
                            )
                          : _selectedModel == null
                              ? const PcEmptyState(
                                  icon: Icons.model_training,
                                  title: 'No model selected',
                                  subtitle:
                                      'Select a model from the left panel',
                                )
                              : ListView.builder(
                                  controller: _scrollCtrl,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _messages.length +
                                      (_chatLoading ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i == _messages.length) {
                                      return const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Row(children: [
                                          SizedBox(width: 8),
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Thinking...'),
                                        ]),
                                      );
                                    }
                                    return _ChatBubble(
                                        msg: _messages[i]);
                                  },
                                ),
                    ),

                    // Input
                    if (state.lmStudioConnected && _selectedModel != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border:
                              Border(top: BorderSide(color: theme.dividerColor)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _chatCtrl,
                              decoration: const InputDecoration(
                                  hintText: 'Message local model...'),
                              style: theme.textTheme.bodyMedium,
                              maxLines: null,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _chatLoading ? null : _sendMessage,
                            icon: const Icon(Icons.send, size: 18),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, String> msg;

  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = msg['role'] == 'user';
    final isError = msg['role'] == 'system';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 24,
              height: 24,
              color: theme.colorScheme.secondary,
              child: const Center(
                  child: Icon(Icons.computer, size: 12)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isUser
                  ? theme.colorScheme.primary.withAlpha(20)
                  : isError
                      ? Colors.red.withAlpha(20)
                      : theme.colorScheme.secondary,
              child: Text(
                msg['content'] ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: isError ? Colors.red : null),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              color: theme.colorScheme.primary,
              child: Center(
                  child: Icon(Icons.person,
                      size: 12,
                      color: theme.colorScheme.onPrimary)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PcSection(
      title: title,
      children: children.map((c) => Padding(
        padding: const EdgeInsets.all(16),
        child: c,
      )).toList(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(
            width: 90,
            child: Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
        Text(value, style: theme.textTheme.bodyMedium),
      ]),
    );
  }
}
