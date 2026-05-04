// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/graph_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _reqCtrl = TextEditingController(
      text:
          'What would public opinion look like if Wuhan University issued a reversal of its disciplinary decision against a certain individual');
  bool _showSettings = false;

  @override
  void dispose() {
    _reqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: MFColors.bg,
      body: Column(children: [
        _buildTopBar(provider),
        Expanded(
            child: _showSettings
                ? _SettingsPanel(
                    onClose: () => setState(() => _showSettings = false))
                : _buildBody(provider)),
      ]),
    );
  }

  Widget _buildTopBar(AppProvider provider) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: MFColors.bg,
        border: Border(bottom: BorderSide(color: MFColors.border)),
      ),
      child: Row(children: [
        Row(children: [
          Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: MFColors.accentBlue,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.waves, color: Colors.white, size: 16)),
          const SizedBox(width: 8),
          const Text('MiroFish',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const Spacer(),
        // System status
        const Icon(Icons.stop, color: MFColors.textMuted, size: 10),
        const SizedBox(width: 6),
        const Text('System Status',
            style: TextStyle(color: MFColors.textSecond, fontSize: 12)),
        const SizedBox(width: 20),
        TextButton(
            onPressed: () {},
            child: const Text('EN/中 ⇄', style: TextStyle(fontSize: 12))),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.star_outline, size: 14),
          label: const Text('Star on GitHub ↗', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: MFColors.textPrimary,
            side: const BorderSide(color: MFColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => setState(() => _showSettings = !_showSettings),
          icon: const Icon(Icons.settings_outlined, size: 18),
          tooltip: 'LLM Settings',
        ),
      ]),
    );
  }

  Widget _buildBody(AppProvider provider) {
    return Row(children: [
      // Left: workflow steps
      Container(
        width: 340,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('System Ready',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: MFColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('System is ready to use',
                style: TextStyle(color: MFColors.textSecond, fontSize: 14)),
            const SizedBox(height: 32),
            // Cyborg AGI Backend indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MFColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: MFColors.accentBlue.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.hub_outlined, color: MFColors.accentBlue, size: 14),
                SizedBox(width: 8),
                Text('Cyborg AGI Backend',
                    style: TextStyle(
                        color: MFColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 24),
            // Use ConstrainedBox or just Column for steps inside ScrollView
            const _WorkflowSteps(),
          ]),
        ),
      ),

      // Divider
      Container(width: 1, color: MFColors.border),

      // Right: input form
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Step 01: Reality seeds
            _InputSection(
              number: '01 / Reality Seeds',
              label: 'PDF',
              child: _FileUploadBox(provider: provider),
            ),
            const SizedBox(height: 24),

            // Step 02: Simulation requirement
            _InputSection(
              number: '>_ 02 / Simulation Requirement',
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: MFColors.border),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: TextField(
                  controller: _reqCtrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: MFColors.textPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Enter simulation requirement...',
                    hintStyle:
                        TextStyle(color: MFColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Spacer(),
              Text('Engine: MiroFish-V0.1',
                  style: const TextStyle(
                      color: MFColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 20),

            // Start build button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final req = _reqCtrl.text.trim();
                  if (req.isEmpty) return;
                  context.read<AppProvider>().startGraphBuild(req);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MFColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('START SIMULATION PIPELINE',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, size: 16),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _WorkflowSteps extends StatelessWidget {
  const _WorkflowSteps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        '01',
        '1. Graph Build',
        'Reality seed extraction & individual/collective memory injection & GraphRAG construction'
      ),
      (
        '02',
        '2. Env Setup',
        'Entity-relationship extraction & persona generation & environment config Agent injection'
      ),
      (
        '03',
        '3. Start Simulation',
        'Dual-platform parallel simulation & auto-parse prediction needs & dynamic temporal memory updates'
      ),
      (
        '04',
        '4. Report Generation',
        'ReportAgent with rich toolset interacts deeply with the post-simulation environment'
      ),
      (
        '05',
        '5. Deep Interaction',
        'Chat with any individual in the simulated world & converse with ReportAgent'
      ),
    ];
    return Column(children: [
      const Align(
        alignment: Alignment.centerLeft,
        child: Row(children: [
          Icon(Icons.diamond_outlined, size: 12, color: MFColors.textMuted),
          SizedBox(width: 6),
          Text('Workflow Steps',
              style: TextStyle(
                  fontSize: 12,
                  color: MFColors.textSecond,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
      const SizedBox(height: 16),
      ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$1,
                  style: const TextStyle(
                      fontSize: 12,
                      color: MFColors.textMuted,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace')),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(s.$2,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(s.$3,
                        style: const TextStyle(
                            fontSize: 11,
                            color: MFColors.textSecond,
                            height: 1.4)),
                  ])),
            ]),
          )),
    ]);
  }
}

class _InputSection extends StatelessWidget {
  final String number;
  final String? label;
  final Widget child;
  const _InputSection({required this.number, required this.child, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(number,
            style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: MFColors.textSecond,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        if (label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                border: Border.all(color: MFColors.border),
                borderRadius: BorderRadius.circular(3)),
            child: Text(label!,
                style:
                    const TextStyle(fontSize: 10, color: MFColors.textSecond)),
          ),
      ]),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

class _FileUploadBox extends StatelessWidget {
  final AppProvider provider;
  const _FileUploadBox({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'txt', 'md', 'json']);
        if (result != null && result.files.isNotEmpty) {
          final f = result.files.first;
          context.read<AppProvider>().setUploadedFile(f.name, f.path ?? '');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MFColors.bgSecond,
          border: Border.all(color: MFColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          const Icon(Icons.description_outlined,
              size: 16, color: MFColors.textSecond),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
            provider.uploadedFileName ?? 'Click to upload PDF / document...',
            style: TextStyle(
                fontSize: 12,
                color: provider.uploadedFileName != null
                    ? MFColors.textPrimary
                    : MFColors.textMuted,
                fontFamily: 'monospace'),
          )),
          if (provider.uploadedFileName != null)
            const Icon(Icons.check_circle,
                size: 14, color: MFColors.accentGreen)
          else
            const Icon(Icons.upload, size: 14, color: MFColors.textMuted),
        ]),
      ),
    );
  }
}

// ── Settings Panel ────────────────────────────────────────────────────────────

class _SettingsPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _SettingsPanel({required this.onClose});
  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late LLMConfig _cfg;
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _localPathCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cfg = context.read<AppProvider>().llmConfig;
    _apiKeyCtrl.text = _cfg.apiKey;
    _baseUrlCtrl.text = _cfg.baseUrl;
    _modelCtrl.text = _cfg.modelName;
    _localPathCtrl.text = _cfg.localModelPath;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    _localPathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 340,
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('LLM Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 18)),
          ]),
          const SizedBox(height: 24),

          // Mode selector
          const Text('Mode',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MFColors.textSecond)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _ModeChip(
                label: '☁ Remote API',
                selected: _cfg.mode == 'api',
                onTap: () => setState(() => _cfg.mode = 'api')),
            _ModeChip(
                label: '🖥 Local LLM',
                selected: _cfg.mode == 'local',
                onTap: () => setState(() => _cfg.mode = 'local')),
          ]),
          const SizedBox(height: 20),

          if (_cfg.mode == 'api') ...[
            _field('API Key', _apiKeyCtrl, hint: 'sk-...', obscure: true),
            const SizedBox(height: 12),
            _field('Base URL', _baseUrlCtrl, hint: 'https://api.openai.com/v1'),
            const SizedBox(height: 12),
            _field('Model Name', _modelCtrl, hint: 'gpt-4o / qwen-plus / etc'),
          ] else ...[
            _field('Model Name', _modelCtrl,
                hint: 'model name shown in LM Studio'),
            const SizedBox(height: 8),
            const Text(
                'LM Studio: load model → start server (port 1234). Ollama: ollama serve. llama.cpp: ./server -m model.gguf',
                style: TextStyle(fontSize: 10, color: MFColors.textMuted)),
            const SizedBox(height: 12),
            _field('llama.cpp Server URL (optional)', _localPathCtrl,
                hint: 'optional: llama.cpp server URL'),
          ],

          const SizedBox(height: 12),
          _field('Temperature',
              TextEditingController(text: _cfg.temperature.toString()),
              hint: '0.0 - 1.0'),
          const SizedBox(height: 24),

          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _cfg.apiKey = _apiKeyCtrl.text;
                  _cfg.baseUrl = _baseUrlCtrl.text;
                  _cfg.modelName = _modelCtrl.text;
                  _cfg.localModelPath = _localPathCtrl.text;
                  context.read<AppProvider>().updateLLMConfig(_cfg);
                  widget.onClose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MFColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Save Configuration'),
              )),
        ]),
      ),
      Container(width: 1, color: MFColors.border),
      const Expanded(
          child: Center(
              child: Text(
                  'Note: Inside Cyborg, the backend is automatically redirected to port 8765.',
                  style: TextStyle(color: MFColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center))),
    ]);
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool obscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MFColors.textSecond)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: MFColors.textMuted, fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: MFColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: MFColors.border),
          ),
        ),
      ),
    ]);
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? MFColors.textPrimary : Colors.transparent,
            border: Border.all(
                color: selected ? MFColors.textPrimary : MFColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : MFColors.textSecond)),
        ),
      );
}
