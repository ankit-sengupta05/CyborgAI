import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/shared_widgets.dart';
import '../../../theme/paperclip_theme.dart';
import '../../chat/screens/chat_screen.dart';

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  bool _isListening = false;
  String _lastTranscript = "";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        const PcPageHeader(
          title: 'Voice Assistant',
          icon: Icons.mic_none_rounded,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Voice Pulse
                _VoicePulse(isListening: _isListening),
                const SizedBox(height: 40),
                Text(
                  _isListening ? 'Listening...' : 'Tap to speak',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ask about project tasks, status, or system health.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 60),
                
                // Auto Task Query Action
                _VoiceActionCard(
                  title: 'Auto Task Query',
                  subtitle: 'Get a status summary of all active tasks',
                  icon: Icons.task_alt_rounded,
                  onTap: () {
                    // Navigate to chat with specialized prompt
                    // In a real app, this would trigger voice-to-text directly
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Analyzing tasks via Voice Assistant...'))
                    );
                  },
                ),
                const SizedBox(height: 16),
                _VoiceActionCard(
                  title: 'System Briefing',
                  subtitle: 'Daily AI summary of your entire organization',
                  icon: Icons.summarize_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VoicePulse extends StatefulWidget {
  final bool isListening;
  const _VoicePulse({required this.isListening});

  @override
  State<_VoicePulse> createState() => _VoicePulseState();
}

class _VoicePulseState extends State<_VoicePulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    if (widget.isListening) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_VoicePulse old) {
    super.didUpdateWidget(old);
    if (widget.isListening) _ctrl.repeat(); else _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isListening)
            ...List.generate(3, (i) => AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final progress = (_ctrl.value + (i * 0.33)) % 1.0;
                return Container(
                  width: 80 + (progress * 100),
                  height: 80 + (progress * 100),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PaperclipTheme.accentCyan.withValues(alpha: 1 - progress),
                      width: 2,
                    ),
                  ),
                );
              },
            )),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [PaperclipTheme.accentCyan, PaperclipTheme.accentCyan.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: PaperclipTheme.accentCyan.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: const Icon(Icons.mic, size: 40, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _VoiceActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _VoiceActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PaperclipTheme.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: PaperclipTheme.accentCyan, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
