// lib/screens/env_setup/env_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/graph_view.dart';

class EnvSetupScreen extends StatefulWidget {
  const EnvSetupScreen({super.key});
  @override State<EnvSetupScreen> createState() => _EnvSetupScreenState();
}

class _EnvSetupScreenState extends State<EnvSetupScreen> {
  int _customRounds = 40;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: MFColors.bg,
      body: Column(children: [
        MFTopBar(
          currentStep: 2, stepName: 'Env Setup', status: 'Ready',
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
    final env = p.envStatus;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // 01: Simulation Instance Init
        MFSectionCard(
          number: '01', title: 'Simulation Instance Init',
          status: _label(env['simulationInit'] ?? 'pending'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _ApiLabel('POST /api/simulation/create'),
            const SizedBox(height: 8),
            const Text('Create a simulation instance and fetch simulation world parameter templates',
              style: TextStyle(fontSize: 12, color: MFColors.textSecond, height: 1.5)),
            if (env['simulationInit'] == 'completed' && p.project != null) ...[
              const SizedBox(height: 16),
              _kvTable({
                'PROJECT ID': p.project!.id,
                'GRAPH ID': p.project!.graphId ?? '—',
                'SIMULATION ID': p.project!.simulationId ?? '—',
                'TASK ID': p.project!.taskId ?? '—',
              }),
            ] else if (env['simulationInit'] == 'processing') ...[
              const SizedBox(height: 12),
              const _ProcessingBar(label: 'Initializing simulation...'),
            ],
          ]),
        ),

        // 02: Generate Agent Profiles
        MFSectionCard(
          number: '02', title: 'Generate Agent Profiles',
          status: _label(env['agentProfiles'] ?? 'pending'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _ApiLabel('POST /api/simulation/prepare'),
            const SizedBox(height: 8),
            const Text('Based on context and related topics from real-world seeds, generate complete Agent profiles for each entity',
              style: TextStyle(fontSize: 12, color: MFColors.textSecond, height: 1.5)),
            if (env['agentProfiles'] == 'completed') ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: MFMetricBox(value: '${p.totalAgents}', label: 'CURRENT AGENTS')),
                Expanded(child: MFMetricBox(value: '${p.expectedTotal}', label: 'EXPECTED TOTAL')),
                Expanded(child: MFMetricBox(value: '${p.relatedTopics}', label: 'RELATED TOPICS')),
              ]),
              const SizedBox(height: 16),
              const Text('GENERATED AGENT PROFILES',
                style: TextStyle(fontSize: 9, color: MFColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (p.agents.isEmpty)
                const Text('No agent profiles generated yet.',
                  style: TextStyle(fontSize: 11, color: MFColors.textMuted))
              else
                SizedBox(
                  height: 160,
                  child: ListView(scrollDirection: Axis.horizontal,
                    children: p.agents.take(6).map((a) => _AgentCard(agent: a)).toList()),
                ),
            ] else if (env['agentProfiles'] == 'processing') ...[
              const SizedBox(height: 12),
              const _ProcessingBar(label: 'Generating agent profiles with LLM...'),
            ],
          ]),
        ),

        // 03: Generate Config
        MFSectionCard(
          number: '03', title: 'Generate Config',
          status: _label(env['generateConfig'] ?? 'pending'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _ApiLabel('POST /api/simulation/prepare'),
            const SizedBox(height: 8),
            const Text('LLM generates dual-platform simulation config parameters based on simulation requirements and Agent profiles',
              style: TextStyle(fontSize: 12, color: MFColors.textSecond, height: 1.5)),
            if (env['generateConfig'] == 'completed') ...[
              const SizedBox(height: 16),
              Row(children: [
                _configTile('Duration', '72 hours'),
                _configTile('Round Duration', '60 min'),
                _configTile('Total Rounds', '72 rounds'),
                _configTile('Active/Hour', '10-27'),
              ]),
              const SizedBox(height: 12),
              _timeTable(),
            ],
          ]),
        ),

        // 04: Initial Activation Orchestration
        MFSectionCard(
          number: '04', title: 'Initial Activation Orchestration',
          status: _label(env['activation'] ?? 'pending'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _ApiLabel('POST /api/simulation/prepare'),
            const SizedBox(height: 8),
            const Text('Orchestrate the initial activation sequence based on narrative direction and Agent profiles',
              style: TextStyle(fontSize: 12, color: MFColors.textSecond, height: 1.5)),
            if (env['activation'] == 'completed' && p.agents.isNotEmpty) ...[
              const SizedBox(height: 16),
              _NarrativeBox(),
            ],
          ]),
        ),

        // 05: Ready
        MFSectionCard(
          number: '05', title: 'Ready',
          status: _label(env['ready'] ?? 'pending'),
          highlighted: env['ready'] == 'in_progress',
          child: Column(children: [
            const _ApiLabel('POST /api/simulation/start'),
            const SizedBox(height: 8),
            const Text('Simulation environment is ready. You can start running the simulation.',
              style: TextStyle(fontSize: 12, color: MFColors.textSecond, height: 1.5)),
            if (env['ready'] == 'in_progress') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MFColors.bgSecond,
                  border: Border.all(color: MFColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Simulation Rounds Config',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Auto-calculated based on time config (72 hours / 60 min per round)',
                    style: TextStyle(fontSize: 11, color: MFColors.accentGreen)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('$_customRounds', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: MFColors.textPrimary)),
                    const SizedBox(width: 6),
                    const Text('rounds', style: TextStyle(color: MFColors.textSecond, fontSize: 13)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(border: Border.all(color: MFColors.border), borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.access_time, size: 10, color: MFColors.textMuted),
                        const SizedBox(width: 4),
                        Text('~${(_customRounds * 0.6).round()}m',
                          style: const TextStyle(fontSize: 10, color: MFColors.textSecond)),
                      ]),
                    ),
                    const Spacer(),
                    // Rounds slider - wrapped to prevent overflow
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Slider(
                          value: _customRounds.toDouble(),
                          min: 5, max: 72,
                          divisions: 67,
                          activeColor: MFColors.accentGreen,
                          onChanged: (v) => setState(() => _customRounds = v.round()),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Need to adjust rounds? Use the slider above →',
                    style: TextStyle(fontSize: 11, color: MFColors.textSecond)),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => context.read<AppProvider>().setStep(AppStep.graphBuild),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: MFColors.border),
                  ),
                  child: const Text('← Back to Graph'),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  onPressed: () => context.read<AppProvider>().startSimulation(_customRounds, requirement: context.read<AppProvider>().reportRequirement.isNotEmpty ? context.read<AppProvider>().reportRequirement : "social simulation"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MFColors.textPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Start Dual-Platform Simulation',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  String _label(String s) {
    switch (s) {
      case 'completed': return 'COMPLETED';
      case 'processing': return 'PROCESSING';
      case 'in_progress': return 'IN PROGRESS';
      case 'complete': return 'COMPLETED';
      default: return 'PENDING';
    }
  }

  Widget _kvTable(Map<String, String> data) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: MFColors.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: data.entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: MFColors.border.withOpacity(0.5)))),
          child: Row(children: [
            SizedBox(width: 130, child: Text(e.key,
              style: const TextStyle(fontSize: 10, color: MFColors.textMuted, letterSpacing: 0.5))),
            Expanded(child: Text(e.value,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: MFColors.textPrimary),
              textAlign: TextAlign.right)),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _configTile(String label, String value) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 10, color: MFColors.textSecond)),
  ]));

  Widget _timeTable() {
    const rows = [
      ('Peak Hours', '19:00, 20:00, 21:00, 22:00', '×1.5'),
      ('Work Hours', '9:00-18:00', '×0.7'),
      ('Morning Hours', '6:00-8:00', '×0.4'),
      ('Off-Peak Hours', '0:00-5:00', '×0.05'),
    ];
    return Column(children: rows.map((r) => Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MFColors.borderLight))),
      child: Row(children: [
        SizedBox(width: 110, child: Text(r.$1, style: const TextStyle(fontSize: 12, color: MFColors.textSecond))),
        Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 12))),
        Text(r.$3, style: const TextStyle(fontSize: 12, color: MFColors.accentBlue, fontWeight: FontWeight.w600)),
      ]),
    )).toList());
  }
}

class _AgentCard extends StatelessWidget {
  final AgentProfile agent;
  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200, margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: MFColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(agent.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: agent.stanceColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(agent.stance.toUpperCase(),
              style: TextStyle(fontSize: 8, color: agent.stanceColor, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(agent.type, style: const TextStyle(fontSize: 10, color: MFColors.textSecond)),
        const SizedBox(height: 6),
        Text(agent.description, style: const TextStyle(fontSize: 10, color: MFColors.textSecond, height: 1.3),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Wrap(spacing: 4, runSpacing: 3,
          children: agent.topics.take(2).map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: MFColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(t, style: const TextStyle(fontSize: 8, color: MFColors.accentBlue)),
          )).toList()),
      ]),
    );
  }
}

class _NarrativeBox extends StatelessWidget {
  const _NarrativeBox();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        border: Border.all(color: MFColors.accentOrange.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 20, height: 20,
            decoration: BoxDecoration(color: MFColors.accentOrange.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.navigation, size: 12, color: MFColors.accentOrange)),
          const SizedBox(width: 8),
          const Text('NARRATIVE GUIDE DIRECTION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 10),
        const Text(
          'Public reaction will be polarized. Some will view it as upholding academic justice, while others may see it as the university bowing to public pressure without genuine governance reform. The discourse will center on the governance capacity and fairness behind the decision.',
          style: TextStyle(fontSize: 12, height: 1.6, color: MFColors.textPrimary)),
        const SizedBox(height: 14),
        const Text('INITIAL HOT TOPICS',
          style: TextStyle(fontSize: 9, color: MFColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Wrap(spacing: 8, runSpacing: 6, children: [
          _HashTag('Wuhan University', MFColors.accentOrange),
          _HashTag('Xiao (the student)', MFColors.accentOrange),
          _HashTag('Disciplinary Action Revocation', MFColors.accentOrange),
          _HashTag('Public Opinion Reaction', MFColors.textSecond),
          _HashTag('Public Sentiment', MFColors.textSecond),
        ]),
      ]),
    );
  }
}

class _HashTag extends StatelessWidget {
  final String label;
  final Color color;
  const _HashTag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      border: Border.all(color: color.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text('# $label', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  );
}

class _ApiLabel extends StatelessWidget {
  final String text;
  const _ApiLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 11, color: MFColors.accentGreen, fontFamily: 'monospace'));
}

class _ProcessingBar extends StatefulWidget {
  final String label;
  const _ProcessingBar({required this.label});
  @override State<_ProcessingBar> createState() => _ProcessingBarState();
}
class _ProcessingBarState extends State<_ProcessingBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(widget.label, style: const TextStyle(fontSize: 11, color: MFColors.textSecond)),
    const SizedBox(height: 8),
    AnimatedBuilder(animation: _ctrl, builder: (_, __) => LinearProgressIndicator(
      value: _ctrl.value, backgroundColor: MFColors.border, color: MFColors.accentGreen, minHeight: 3)),
  ]);
}
