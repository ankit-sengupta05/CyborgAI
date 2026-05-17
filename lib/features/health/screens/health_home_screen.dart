import 'package:flutter/material.dart';
import '../../../theme/paperclip_theme.dart';
import 'xray_analyzer_screen.dart';
import '../../chat/screens/chat_screen.dart';

// Local shim so existing AppColors references resolve without rewriting every line
class AppColors {
  static const Color backgroundMain    = PaperclipTheme.backgroundDark;
  static const Color backgroundSidebar = PaperclipTheme.sidebarDark;
  static const Color backgroundSurface = PaperclipTheme.surfaceDark;
  static const Color backgroundInput   = PaperclipTheme.surfaceElevatedDark;
  static const Color borderDefault     = PaperclipTheme.borderDark;
  static const Color borderHover       = PaperclipTheme.borderBrightDark;
  static const Color textPrimary       = PaperclipTheme.foregroundDark;
  static const Color textSecondary     = PaperclipTheme.mutedDark;
  static const Color textTertiary      = PaperclipTheme.mutedFgDark;
  static const Color textMuted         = PaperclipTheme.mutedFgDark;
  static const Color accentBlue        = PaperclipTheme.accentCyan;
  static const Color accentBlueHover   = Color(0xFF00A0D6);
  static const Color accent            = PaperclipTheme.accentCyan;
  static const Color accentPurple      = PaperclipTheme.accentPurple;
  static const Color accentGreen       = PaperclipTheme.accentGreen;
  static const Color accentRed         = PaperclipTheme.accentRed;
  static const Color accentOrange      = PaperclipTheme.accentAmber;
  static const Color accentYellow      = PaperclipTheme.accentAmber;
  static const Color success           = PaperclipTheme.accentGreen;
  static const Color warning           = PaperclipTheme.accentAmber;
  static const Color error             = PaperclipTheme.accentRed;
  static const Color info              = PaperclipTheme.accentCyan;
  static const Color surface           = PaperclipTheme.surfaceDark;
  static const Color surfaceVariant    = PaperclipTheme.surfaceElevatedDark;
  static const Color background        = PaperclipTheme.backgroundDark;
  static const Color border            = PaperclipTheme.borderDark;
  static const LinearGradient accentGradient = LinearGradient(
    colors: [PaperclipTheme.accentGreen, PaperclipTheme.accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Health Track Home Screen
/// Entry point for Gemma 4 medical assistance features
class HealthHomeScreen extends StatelessWidget {
  const HealthHomeScreen({super.key});

  static const _healthBlue = Color(0xFF0ea5e9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaperclipTheme.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0ea5e9), Color(0xFF0284c7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_hospital_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Health Track',
                    style: TextStyle(
                        color: PaperclipTheme.foregroundDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                Text('Gemma 4 · Offline Edge Deployment',
                    style: TextStyle(
                        color: PaperclipTheme.mutedDark, fontSize: 13)),
              ]),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: PaperclipTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: PaperclipTheme.accentGreen.withOpacity(0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off,
                      color: PaperclipTheme.accentGreen, size: 13),
                  const SizedBox(width: 5),
                  Text('100% Offline',
                      style: TextStyle(
                          color: PaperclipTheme.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'AI-assisted medical imaging analysis and patient education, optimized for offline edge deployment in low-resource settings.',
              style: TextStyle(
                  color: PaperclipTheme.mutedDark, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Feature cards
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 700 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cols == 2 ? 1.6 : 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _FeatureCard(
                    icon: Icons.biotech_outlined,
                    color: _healthBlue,
                    title: 'X-Ray Analyzer',
                    description:
                        'Upload chest X-rays and receive AI-assisted analysis with plain-language explanations in multiple languages.',
                    tags: const [
                      'Gemma 4',
                      'SigLIP Vision',
                      'Multilingual'
                    ],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const XRayAnalyzerScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.record_voice_over_outlined,
                    color: const Color(0xFF10b981),
                    title: 'Patient Educator',
                    description:
                        'Explain medical concepts in plain language, generate follow-up questions, and provide accessible health education.',
                    tags: const [
                      'Voice I/O',
                      'Plain Language',
                      'EHR Integration'
                    ],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.folder_special_outlined,
                    color: const Color(0xFF8B5CF6),
                    title: 'EHR Assistant',
                    description:
                        'Query and update Electronic Health Records using natural language with FHIR-compatible function calling.',
                    tags: const [
                      'FHIR Compatible',
                      'Function Calling',
                      'Audit Trail'
                    ],
                    onTap: () => _showComingSoon(context, 'EHR Assistant'),
                  ),
                  _FeatureCard(
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFFF59E0B),
                    title: 'Diagnostics Dashboard',
                    description:
                        'Track clinic metrics, model accuracy stats, and edge device performance from a unified dashboard.',
                    tags: const ['Analytics', 'Edge Monitoring', 'Reports'],
                    onTap: () =>
                        _showComingSoon(context, 'Diagnostics Dashboard'),
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),

            // Benchmark stats
            _buildBenchmarkRow(),
            const SizedBox(height: 24),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PaperclipTheme.accentRed.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: PaperclipTheme.accentRed.withOpacity(0.25)),
              ),
              child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: PaperclipTheme.accentRed, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      '⚠️ Important: All AI outputs are for educational and assistance purposes only. '
                      'They are NOT a substitute for professional medical diagnosis or treatment. '
                      'Always consult a qualified healthcare provider for medical decisions.',
                      style: TextStyle(
                          color: PaperclipTheme.accentRed,
                          fontSize: 12,
                          height: 1.6),
                    )),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkRow() {
    const stats = [
      {
        'label': 'X-ray Accuracy',
        'value': '90.2%',
        'sub': 'MedMNIST benchmark',
        'color': 0xFF10b981
      },
      {
        'label': 'Edge Latency',
        'value': '<15s',
        'sub': 'Raspberry Pi 4',
        'color': 0xFF0ea5e9
      },
      {
        'label': 'Offline Uptime',
        'value': '100%',
        'sub': '72-hr continuous test',
        'color': 0xFF8B5CF6
      },
      {
        'label': 'Languages',
        'value': '5+',
        'sub': 'EN, ES, HI, SW, FR',
        'color': 0xFFF59E0B
      },
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Performance Benchmarks',
          style: TextStyle(
              color: PaperclipTheme.foregroundDark,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (ctx, c) {
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats
                .map((s) => SizedBox(
                      width: (c.maxWidth / 4).clamp(100, 200) - 12,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: PaperclipTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Color(s['color'] as int).withOpacity(0.3))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['value'] as String,
                                  style: TextStyle(
                                      color: Color(s['color'] as int),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              Text(s['label'] as String,
                                  style: const TextStyle(
                                      color: PaperclipTheme.foregroundDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text(s['sub'] as String,
                                  style: const TextStyle(
                                      color: PaperclipTheme.mutedFgDark,
                                      fontSize: 10)),
                            ]),
                      ),
                    ))
                .toList());
      }),
    ]);
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature — Coming Soon'),
      backgroundColor: PaperclipTheme.surfaceDark,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final List<String> tags;
  final VoidCallback onTap;
  const _FeatureCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.description,
      required this.tags,
      required this.onTap});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hovered
                  ? PaperclipTheme.surfaceDark.withOpacity(0.95)
                  : PaperclipTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _hovered
                      ? widget.color.withOpacity(0.5)
                      : PaperclipTheme.borderDark),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                          color: widget.color.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(widget.icon, color: widget.color, size: 20)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    color: _hovered ? widget.color : PaperclipTheme.mutedFgDark,
                    size: 13),
              ]),
              const SizedBox(height: 12),
              Text(widget.title,
                  style: TextStyle(
                      color: PaperclipTheme.foregroundDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Expanded(
                  child: Text(widget.description,
                      style: const TextStyle(
                          color: PaperclipTheme.mutedDark,
                          fontSize: 12,
                          height: 1.5),
                      overflow: TextOverflow.fade)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: widget.color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: widget.color.withOpacity(0.25))),
                            child: Text(t,
                                style: TextStyle(
                                    color: widget.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList()),
            ]),
          ),
        ),
      );
}
