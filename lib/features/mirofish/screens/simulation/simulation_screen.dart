// lib/screens/simulation/simulation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/graph_view.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final _reqCtrl = TextEditingController(
      text:
          'What would be the public opinion trend if Wuhan University issued a notice revoking the disciplinary action against Xiao');

  @override
  void dispose() {
    _reqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: MFColors.bg,
      body: Column(children: [
        MFTopBar(
          currentStep: 3,
          stepName: 'Simulation',
          status: p.simRunning ? 'Running' : 'Completed',
          activeView: p.viewMode.index,
          onGraph: () => p.setViewMode(ViewMode.graph),
          onSplit: () => p.setViewMode(ViewMode.split),
          onWorkbench: () => p.setViewMode(ViewMode.workbench),
        ),
        Expanded(child: _buildBody(context, p)),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, AppProvider p) {
    switch (p.viewMode) {
      case ViewMode.graph:
        return _graphPanel(p);
      case ViewMode.workbench:
        return _workbenchPanel(context, p);
      default:
        return Row(children: [
          Expanded(flex: 3, child: _graphPanel(p)),
          Container(width: 1, color: MFColors.border),
          SizedBox(width: 460, child: _workbenchPanel(context, p)),
        ]);
    }
  }

  Widget _graphPanel(AppProvider p) => Container(
        color: const Color(0xFFF5F5F5),
        child: GraphView(data: p.graphData, showEdgeLabels: p.showEdgeLabels),
      );

  Widget _workbenchPanel(BuildContext context, AppProvider p) {
    return Column(children: [
      // Platform status bar
      _PlatformStatusBar(p: p),
      // Content
      Expanded(child: _SimFeed(p: p, reqCtrl: _reqCtrl)),
    ]);
  }
}

class _PlatformStatusBar extends StatelessWidget {
  final AppProvider p;
  const _PlatformStatusBar({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MFColors.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // INFO PLAZA
          _PlatformCard(
            icon: Icons.language,
            label: 'INFO PLAZA',
            round: p.plazaRound,
            totalRounds: p.plazaTotalRounds,
            acts: p.plazaActs,
            done: !p.simRunning && p.plazaRound > 0,
          ),
          const SizedBox(width: 10),
          // TOPIC COMMUNITY
          _PlatformCard(
            icon: Icons.chat_bubble_outline,
            label: 'TOPIC COMMUNITY',
            round: p.communityRound,
            totalRounds: p.plazaTotalRounds,
            acts: p.communityActs,
            done: !p.simRunning && p.communityRound > 0,
          ),
          const SizedBox(width: 10),
          // Generate Report button (when complete)
          if (!p.simRunning && p.plazaRound > 0)
            ElevatedButton(
              onPressed: () => _showReportDialog(context, p),
              style: ElevatedButton.styleFrom(
                backgroundColor: MFColors.textPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('GENERATE REPORT →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
    );
  }

  void _showReportDialog(BuildContext context, AppProvider p) {
    final ctrl = TextEditingController(
        text:
            'What would be the public opinion trend if Wuhan University issued a notice revoking the disciplinary action against Xiao');
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Generate Analysis Report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                  width: 400,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Enter your research requirement:',
                        style: TextStyle(
                            fontSize: 12, color: MFColors.textSecond)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: ctrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4)),
                          hintText:
                              'What would be the public opinion trend if...',
                          contentPadding: const EdgeInsets.all(10),
                        )),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Use microtask to avoid building during navigator transition
                    Future.microtask(() => p.generateReport(ctrl.text));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: MFColors.textPrimary,
                      foregroundColor: Colors.white),
                  child: const Text('Generate'),
                ),
              ],
            ));
  }
}

class _PlatformCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int round;
  final int totalRounds;
  final int acts;
  final bool done;

  const _PlatformCard({
    required this.icon,
    required this.label,
    required this.round,
    required this.totalRounds,
    required this.acts,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
            color:
                done ? MFColors.accentGreen.withOpacity(0.4) : MFColors.border),
        borderRadius: BorderRadius.circular(6),
        color: done ? MFColors.accentGreen.withOpacity(0.03) : MFColors.bg,
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: MFColors.textSecond),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const Spacer(),
            if (done)
              const Icon(Icons.check, size: 12, color: MFColors.accentGreen),
          ]),
          const SizedBox(height: 2),
          Text(
              'ROUND $round/$totalRounds   ELAPSED TIME ${round}h 0m   ACTS $acts',
              style: const TextStyle(fontSize: 9, color: MFColors.textMuted)),
        ])),
      ]),
    );
  }
}

class _SimFeed extends StatelessWidget {
  final AppProvider p;
  final TextEditingController reqCtrl;
  const _SimFeed({required this.p, required this.reqCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Stats bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MFColors.border))),
        child: Row(children: [
          const Text('TOTAL EVENTS:',
              style: TextStyle(fontSize: 11, color: MFColors.textSecond)),
          const SizedBox(width: 6),
          Text('${p.totalEvents}',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          const Icon(Icons.language, size: 12, color: MFColors.textSecond),
          const SizedBox(width: 4),
          Text('${p.plazaActs}', style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 12),
          const Icon(Icons.chat_bubble_outline,
              size: 12, color: MFColors.textSecond),
          const SizedBox(width: 4),
          Text('${p.communityActs}', style: const TextStyle(fontSize: 11)),
        ]),
      ),
      // Events feed
      Expanded(
        child: p.simEvents.isEmpty
            ? Center(
                child: p.simRunning
                    ? const Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(
                            strokeWidth: 2, color: MFColors.accentGreen),
                        SizedBox(height: 12),
                        Text('Simulation running...',
                            style: TextStyle(
                                color: MFColors.textSecond, fontSize: 12)),
                      ])
                    : const Text(
                        'No events yet. Start simulation to see activity.',
                        style:
                            TextStyle(color: MFColors.textMuted, fontSize: 12)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                reverse: true,
                itemCount: p.simEvents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 0),
                itemBuilder: (_, i) =>
                    _EventCard(event: p.simEvents[p.simEvents.length - 1 - i]),
              ),
      ),
    ]);
  }
}

class _EventCard extends StatelessWidget {
  final SimEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MFColors.nodeColor(event.agentType).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(
                    event.agentName.isNotEmpty
                        ? event.agentName[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: MFColors.nodeColor(event.agentType)))),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(event.agentName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text(event.agentType.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9,
                        color: MFColors.textMuted,
                        letterSpacing: 0.5)),
              ])),
          // Platform icon
          Icon(
              event.platform == 'plaza'
                  ? Icons.language
                  : Icons.chat_bubble_outline,
              size: 12,
              color: MFColors.textMuted),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                border: Border.all(color: MFColors.border),
                borderRadius: BorderRadius.circular(3)),
            child: Text(event.eventType.toUpperCase(),
                style:
                    const TextStyle(fontSize: 8, color: MFColors.textSecond)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MFColors.bgSecond,
            border: Border.all(color: MFColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(event.content,
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: MFColors.textPrimary)),
        ),
        const SizedBox(height: 4),
        Text(event.time,
            style: const TextStyle(fontSize: 10, color: MFColors.textMuted)),
      ]),
    );
  }
}
