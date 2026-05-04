import 'package:flutter/material.dart';

class MFColors {
  static const bg = Color(0xFFFFFFFF);
  static const bgSecond = Color(0xFFF8F9FA);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgDark = Color(0xFF0A0A0A);
  static const bgConsole = Color(0xFF0D0D0D);
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF0F172A); // Darker Slate
  static const textSecond = Color(0xFF475569);  // Darker gray-slate
  static const textMuted = Color(0xFF64748B);   // Slate-gray
  static const textInverse = Color(0xFFFFFFFF);
  static const textConsole = Color(0xFF22C55E);
  static const accentGreen = Color(0xFF22C55E);
  static const accentOrange = Color(0xFFF97316);
  static const accentRed = Color(0xFFEF4444);
  static const accentBlue = Color(0xFF3B82F6);
  static const accentPurple = Color(0xFF8B5CF6);
  static const accentYellow = Color(0xFFEAB308);
  static const nodeUniversity = Color(0xFFFF6B35);
  static const nodeEntity = Color(0xFF4A90D9);
  static const nodeAlumni = Color(0xFF9B59B6);
  static const nodeOrganization = Color(0xFF27AE60);
  static const nodeStudent = Color(0xFFE74C3C);
  static const nodeProfessor = Color(0xFFE67E22);
  static const nodePerson = Color(0xFF3498DB);
  static const nodeMediaOutlet = Color(0xFF8E44AD);
  static const nodeLegalAuthority = Color(0xFF1ABC9C);
  static const nodeOpinionLeader = Color(0xFFF39C12);
  static const nodeGovAgency = Color(0xFF2ECC71);

  static Color nodeColor(String type) {
    final t = type.toLowerCase().replaceAll(' ','').replaceAll('_','');
    switch (t) {
      case 'university':       return const Color(0xFFFF6B35);
      case 'entity':           return const Color(0xFF4A90D9);
      case 'alumni':           return const Color(0xFF9B59B6);
      case 'organization':     return const Color(0xFF27AE60);
      case 'student':          return const Color(0xFFE74C3C);
      case 'professor':        return const Color(0xFFE67E22);
      case 'person':           return const Color(0xFF3498DB);
      case 'mediaoutlet':      return const Color(0xFF8E44AD);
      case 'legalauthority':   return const Color(0xFF1ABC9C);
      case 'opinionleader':    return const Color(0xFFF39C12);
      case 'governmentagency': return const Color(0xFF2ECC71);
      case 'ngo':              return const Color(0xFF16A085);
      case 'individual':       return const Color(0xFF3498DB);
      case 'public':           return const Color(0xFFF39C12);
      case 'decision':         return const Color(0xFFE84393);
      default:                 return const Color(0xFF4A90D9);
    }
  }
}

class MFTheme {
  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: MFColors.accentGreen, brightness: Brightness.light),
    scaffoldBackgroundColor: MFColors.bg,
    useMaterial3: true,
    dividerColor: MFColors.border,
    cardColor: MFColors.bgCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: MFColors.bg,
      foregroundColor: MFColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

// ── Reusable UI components ──────────────────────────────────────────────────

class MFBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const MFBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? MFColors.accentGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class MFStatusBadge extends StatelessWidget {
  final String status;
  const MFStatusBadge(this.status, {super.key});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'build complete': case 'completed': case 'complete': return MFColors.accentGreen;
      case 'processing': case 'in progress': case 'in_progress': return MFColors.accentOrange;
      case 'ready': return MFColors.accentGreen;
      default: return MFColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) => MFBadge(label: status.toUpperCase(), color: _color);
}

class MFSectionCard extends StatelessWidget {
  final String number;
  final String title;
  final String status;
  final Widget child;
  final bool highlighted;

  const MFSectionCard({
    super.key,
    required this.number,
    required this.title,
    required this.status,
    required this.child,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MFColors.bgCard,
        border: Border.all(color: highlighted
            ? MFColors.accentOrange.withOpacity(0.5)
            : MFColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (highlighted) BoxShadow(color: MFColors.accentOrange.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MFColors.textPrimary)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          MFStatusBadge(status),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}

class MFMetricBox extends StatelessWidget {
  final String value;
  final String label;
  const MFMetricBox({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: MFColors.textPrimary)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: MFColors.textSecond, letterSpacing: 0.3)),
  ]);
}

class MFEntityTag extends StatelessWidget {
  final String label;
  const MFEntityTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6, bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: MFColors.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, color: MFColors.textPrimary)),
  );
}

class MFConsoleLog extends StatelessWidget {
  final List<String> logs;
  final String? sessionId;
  final String? label;
  const MFConsoleLog({super.key, required this.logs, this.sessionId, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      color: MFColors.bgConsole,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
          child: Row(children: [
            Text(label ?? 'SYSTEM DASHBOARD', style: const TextStyle(color: Color(0xFF555555), fontSize: 10, letterSpacing: 1)),
            const Spacer(),
            if (sessionId != null)
              Text(sessionId!, style: const TextStyle(color: Color(0xFF444444), fontSize: 10, fontFamily: 'monospace')),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(10),
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final line = logs[logs.length - 1 - i];
              return Text(line, style: const TextStyle(
                color: MFColors.textConsole, fontSize: 11,
                fontFamily: 'monospace', height: 1.6,
              ));
            },
          ),
        ),
      ]),
    );
  }
}

class MFTopBar extends StatelessWidget {
  final int currentStep;
  final String stepName;
  final String status;
  final VoidCallback? onGraph;
  final VoidCallback? onSplit;
  final VoidCallback? onWorkbench;
  final int activeView; // 0=graph, 1=split, 2=workbench

  const MFTopBar({
    super.key,
    required this.currentStep,
    required this.stepName,
    required this.status,
    this.onGraph,
    this.onSplit,
    this.onWorkbench,
    this.activeView = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: MFColors.bg,
        border: Border(bottom: BorderSide(color: MFColors.border)),
      ),
      child: Row(children: [
        // Logo
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: MFColors.accentBlue, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.waves, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text('MiroFish', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(width: 32),
        // View toggle
        _ViewToggle(active: activeView, onGraph: onGraph, onSplit: onSplit, onWorkbench: onWorkbench),
        const Spacer(),
        // Step indicator & Actions
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Step $currentStep/5', style: const TextStyle(color: MFColors.textSecond, fontSize: 11)),
              const SizedBox(width: 6),
              Text(stepName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Container(width: 6, height: 6, decoration: const BoxDecoration(
                color: MFColors.accentGreen, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(status, style: const TextStyle(color: MFColors.accentGreen, fontSize: 11)),
              const SizedBox(width: 16),
              TextButton(onPressed: () {}, child: const Text('EN/中 ⇄', style: TextStyle(fontSize: 11))),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.star_outline, size: 12),
                label: const Text('Star', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MFColors.textPrimary,
                  side: const BorderSide(color: MFColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final int active;
  final VoidCallback? onGraph;
  final VoidCallback? onSplit;
  final VoidCallback? onWorkbench;

  const _ViewToggle({required this.active, this.onGraph, this.onSplit, this.onWorkbench});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MFColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tab('Graph', 0, onGraph),
        _divider(),
        _tab('Split', 1, onSplit),
        _divider(),
        _tab('Workbench', 2, onWorkbench),
      ]),
    );
  }

  Widget _tab(String label, int idx, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active == idx ? MFColors.textPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: active == idx ? MFColors.textInverse : MFColors.textSecond,
      )),
    ),
  );

  Widget _divider() => Container(width: 1, height: 28, color: MFColors.border);
}
