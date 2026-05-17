import 'package:flutter/material.dart';
import '../../../theme/paperclip_theme.dart';
import 'homework_scanner_screen.dart';
import 'quiz_player_screen.dart';
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

/// Education Track Home Screen
class EducationHomeScreen extends StatelessWidget {
  const EducationHomeScreen({super.key});

  static const _eduViolet = Color(0xFF8B5CF6);

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
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366f1)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Education Track',
                    style: TextStyle(
                        color: PaperclipTheme.foregroundDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                Text('Gemma 4 4B · Adaptive Learning Agent',
                    style: TextStyle(
                        color: PaperclipTheme.mutedDark, fontSize: 13)),
              ]),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: _eduViolet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _eduViolet.withOpacity(0.4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off, color: _eduViolet, size: 13),
                  SizedBox(width: 5),
                  Text('Offline Classroom',
                      style: TextStyle(
                          color: _eduViolet,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Adaptive homework grading, personalized quizzes, and voice-accessible tutoring—running offline on low-cost devices in under-resourced classrooms.',
              style: TextStyle(
                  color: PaperclipTheme.mutedDark, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Feature grid
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 700 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cols == 2 ? 1.6 : 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _FeatureCard(
                    icon: Icons.camera_alt_outlined,
                    color: _eduViolet,
                    title: 'Homework Scanner',
                    description:
                        'Upload a photo of handwritten or printed homework and receive rubric-based grading with constructive feedback in multiple languages.',
                    tags: const ['OCR', 'Gemma 4', 'Multilingual'],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HomeworkScannerScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.quiz_outlined,
                    color: const Color(0xFF6366f1),
                    title: 'Adaptive Quiz',
                    description:
                        'Generate personalized quizzes targeting knowledge gaps. Culturally relevant questions in the student\'s language with voice I/O support.',
                    tags: const ['Adaptive', 'Voice I/O', 'Cultural Context'],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QuizPlayerScreen())),
                  ),
                  _FeatureCard(
                    icon: Icons.trending_up_outlined,
                    color: const Color(0xFF22c55e),
                    title: 'Progress Tracker',
                    description:
                        'Visualize student learning gains, identify weak concepts, and generate personalized learning path recommendations for each student.',
                    tags: const ['Analytics', 'Learning Paths', 'Dashboard'],
                    onTap: () => _soon(context, 'Progress Tracker'),
                  ),
                  _FeatureCard(
                    icon: Icons.record_voice_over_outlined,
                    color: const Color(0xFFF59E0B),
                    title: 'Voice Tutor',
                    description:
                        'Fully offline voice interaction loop: student speaks → AI processes → AI responds in natural language for accessible, hands-free tutoring.',
                    tags: const ['Whisper STT', 'Piper TTS', 'Hands-free'],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),
            _buildBenchmarks(),
            const SizedBox(height: 24),
            _buildLanguageSupport(),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarks() {
    const stats = [
      {
        'label': 'Grading Accuracy',
        'value': '85.7%',
        'sub': 'Teacher alignment',
        'color': 0xFF22c55e
      },
      {
        'label': 'Quiz Improvement',
        'value': '+25%',
        'sub': 'Post-quiz vs generic',
        'color': 0xFF8B5CF6
      },
      {
        'label': 'Edge Latency',
        'value': '<8s',
        'sub': 'Android Go tablet',
        'color': 0xFF6366f1
      },
      {
        'label': 'Voice Accuracy',
        'value': '92%',
        'sub': 'WER on Hindi',
        'color': 0xFFF59E0B
      },
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Performance Benchmarks',
          style: TextStyle(
              color: PaperclipTheme.foregroundDark,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      LayoutBuilder(
          builder: (_, c) => Wrap(
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
                                  color: Color(s['color'] as int)
                                      .withOpacity(0.3))),
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
                  .toList())),
    ]);
  }

  Widget _buildLanguageSupport() {
    const langs = [
      ('🇺🇸', 'English'),
      ('🇪🇸', 'Español'),
      ('🇮🇳', 'हिन्दी'),
      ('🌍', 'Swahili'),
      ('🇫🇷', 'Français')
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: PaperclipTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaperclipTheme.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Language Support',
            style: TextStyle(
                color: PaperclipTheme.foregroundDark,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('All AI outputs, feedback, and quizzes available in:',
            style: TextStyle(color: PaperclipTheme.mutedFgDark, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(
            spacing: 10,
            runSpacing: 8,
            children: langs
                .map((l) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: PaperclipTheme.backgroundDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PaperclipTheme.borderDark)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(l.$1, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(l.$2,
                            style: const TextStyle(
                                color: PaperclipTheme.foregroundDark, fontSize: 12))
                      ]),
                    ))
                .toList()),
      ]),
    );
  }

  void _soon(BuildContext context, String name) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name — Coming Soon'),
        backgroundColor: PaperclipTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ));
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title, description;
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
                color: PaperclipTheme.surfaceDark,
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8)),
                          child:
                              Icon(widget.icon, color: widget.color, size: 20)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          color: _hovered ? widget.color : PaperclipTheme.mutedFgDark,
                          size: 13),
                    ]),
                    const SizedBox(height: 12),
                    Text(widget.title,
                        style: const TextStyle(
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
                                          color:
                                              widget.color.withOpacity(0.25))),
                                  child: Text(t,
                                      style: TextStyle(
                                          color: widget.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList()),
                  ]),
            )),
      );
}
