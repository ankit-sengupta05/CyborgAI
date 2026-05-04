// lib/screens/graph_build/graph_build_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/graph_view.dart';

class GraphBuildScreen extends StatelessWidget {
  const GraphBuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: MFColors.bg,
      body: Column(children: [
        MFTopBar(
          currentStep: 1,
          stepName: 'Graph Build',
          status: 'Ready',
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
        return _graphPanel(context, p);
      case ViewMode.workbench:
        return _workbenchPanel(context, p);
      case ViewMode.split:
      default:
        return Row(children: [
          Expanded(flex: 3, child: _graphPanel(context, p)),
          Container(width: 1, color: MFColors.border),
          SizedBox(width: 420, child: _workbenchPanel(context, p)),
        ]);
    }
  }

  Widget _graphPanel(BuildContext context, AppProvider p) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: GraphView(
        data: p.graphData,
        showEdgeLabels: p.showEdgeLabels,
        onRefresh: () => p.addLog(
            'Graph refreshed: ${p.graphData.nodes.length} nodes, ${p.graphData.edges.length} edges'),
      ),
    );
  }

  Widget _workbenchPanel(BuildContext context, AppProvider p) {
    return Container(
      color: MFColors.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Step 01: Ontology Generation
          MFSectionCard(
            number: '01',
            title: 'Ontology Generation',
            status: _statusLabel(p.buildStatus['ontology'] ?? 'pending'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _ApiLabel('POST /api/graph/ontology/generate'),
              const SizedBox(height: 10),
              const Text(
                  'LLM analyzes document content and simulation requirements, extracts real-world seeds, and automatically generates an appropriate ontology structure',
                  style: TextStyle(
                      fontSize: 12, color: MFColors.textSecond, height: 1.5)),
              if (p.entityTypes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _tagSection('GENERATED ENTITY TYPES', p.entityTypes),
                const SizedBox(height: 12),
                _tagSection('GENERATED RELATION TYPES', p.relationTypes),
              ] else if (p.buildStatus['ontology'] == 'processing') ...[
                const SizedBox(height: 16),
                const _ProcessingBar(label: 'Analyzing with LLM...'),
              ],
            ]),
          ),

          // Step 02: GraphRAG Build
          MFSectionCard(
            number: '02',
            title: 'GraphRAG Build',
            status: _statusLabel(p.buildStatus['graphrag'] ?? 'pending'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _ApiLabel('POST /api/graph/build'),
              const SizedBox(height: 10),
              const Text(
                  'Based on the generated ontology, automatically chunks documents and calls Zep to build a knowledge graph, extracting entities and relations, forming temporal memory and community summaries',
                  style: TextStyle(
                      fontSize: 12, color: MFColors.textSecond, height: 1.5)),
              if (p.buildStatus['graphrag'] == 'complete' ||
                  p.buildStatus['buildComplete'] != 'pending') ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: MFMetricBox(
                          value: '${p.entityNodes}', label: 'ENTITY NODES')),
                  Expanded(
                      child: MFMetricBox(
                          value: '${p.relationEdges}',
                          label: 'RELATION EDGES')),
                  Expanded(
                      child: MFMetricBox(
                          value: '${p.schemaTypes}', label: 'SCHEMA TYPES')),
                ]),
              ] else if (p.buildStatus['graphrag'] == 'processing') ...[
                const SizedBox(height: 16),
                const _ProcessingBar(label: 'Building knowledge graph...'),
              ],
            ]),
          ),

          // Step 03: Build Complete → proceed
          MFSectionCard(
            number: '03',
            title: 'Build Complete',
            status: _statusLabel(p.buildStatus['buildComplete'] ?? 'pending'),
            highlighted: p.buildStatus['buildComplete'] == 'in_progress',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _ApiLabel('POST /api/simulation/create'),
              const SizedBox(height: 10),
              const Text(
                  'Graph build is complete. Proceed to the next step for environment setup.',
                  style: TextStyle(
                      fontSize: 12, color: MFColors.textSecond, height: 1.5)),
              if (p.buildStatus['buildComplete'] == 'in_progress') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => p.proceedToEnvSetup(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MFColors.textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Go to Env Setup →',
                        style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'complete':
        return 'BUILD COMPLETE';
      case 'processing':
        return 'PROCESSING';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      default:
        return 'PENDING';
    }
  }

  Widget _tagSection(String title, List<String> tags) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 9,
                color: MFColors.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) => MFEntityTag(t)).toList()),
      ]);
}

class _ApiLabel extends StatelessWidget {
  final String text;
  const _ApiLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11, color: MFColors.accentGreen, fontFamily: 'monospace'));
}

class _ProcessingBar extends StatefulWidget {
  final String label;
  const _ProcessingBar({required this.label});
  @override
  State<_ProcessingBar> createState() => _ProcessingBarState();
}

class _ProcessingBarState extends State<_ProcessingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.label,
            style: const TextStyle(fontSize: 11, color: MFColors.textSecond)),
        const SizedBox(height: 8),
        AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => LinearProgressIndicator(
                  value: _ctrl.value,
                  backgroundColor: MFColors.border,
                  color: MFColors.accentGreen,
                  minHeight: 3,
                )),
      ]);
}
