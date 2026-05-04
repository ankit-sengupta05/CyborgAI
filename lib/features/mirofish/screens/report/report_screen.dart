// lib/screens/report/report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../utils/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: MFColors.bg,
      body: Material(
        color: MFColors.bg,
        child: Column(children: [
          MFTopBar(
            currentStep: 4, stepName: 'Report',
            status: p.reportGenerating ? 'Generating' : 'Completed',
            activeView: 2, // workbench default for report
            onGraph: () => p.setViewMode(ViewMode.graph),
            onSplit: () => p.setViewMode(ViewMode.split),
            onWorkbench: () => p.setViewMode(ViewMode.workbench),
          ),
          Expanded(child: _buildBody(context, p)),
        ]),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppProvider p) {
    return Row(children: [
      // Left: report content
      Expanded(
        flex: 3,
        child: Container(
          padding: const EdgeInsets.all(32),
          child: p.reportContent.isEmpty
            ? Center(child: p.reportGenerating
                ? const Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(strokeWidth: 2, color: MFColors.accentGreen),
                    SizedBox(height: 16),
                    Text('Generating report with ReportAgent...', style: TextStyle(color: MFColors.textSecond)),
                  ])
                : const Text('No report yet.', style: TextStyle(color: MFColors.textMuted)))
            : Markdown(
                data: p.reportContent,
                styleSheet: MarkdownStyleSheet(
                  h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MFColors.textPrimary),
                  h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MFColors.textPrimary),
                  p: const TextStyle(fontSize: 13, height: 1.7, color: MFColors.textPrimary),
                  listBullet: const TextStyle(fontSize: 13, color: MFColors.textSecond),
                  strong: const TextStyle(fontWeight: FontWeight.bold, color: MFColors.textPrimary),
                ),
              ),
        ),
      ),
      // Right: workbench trace
      Container(width: 1, color: MFColors.border),
      SizedBox(
        width: 420,
        child: _WorkbenchTrace(p: p),
      ),
    ]);
  }
}

class _WorkbenchTrace extends StatelessWidget {
  final AppProvider p;
  const _WorkbenchTrace({required this.p});

  @override
  Widget build(BuildContext context) {
    final sections = p.reportSections;
    final done = !p.reportGenerating && p.reportContent.isNotEmpty;

    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MFColors.border))),
        child: Row(children: [
          Text(
            done ? 'SECTIONS ${sections.length}/${sections.length}' : 'GENERATING...',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(width: 12),
          if (done) ...[
            _pill('ELAPSED ${(sections.length * 2 + 6)}m ${(sections.length * 3 + 50)}s'),
            const SizedBox(width: 8),
            _pill('TOOLS ${sections.length * 4 + 2}'),
            const SizedBox(width: 8),
            const MFStatusBadge('COMPLETED'),
          ] else if (p.reportGenerating) ...[
            const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: MFColors.accentOrange)),
            const SizedBox(width: 6),
            const Text('Writing...', style: TextStyle(fontSize: 11, color: MFColors.textSecond)),
          ],
        ]),
      ),

      // Section list + CTA
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Sections
          if (sections.isNotEmpty)
            ...sections.map((s) => _SectionRow(section: s))
          else
            ...['Planning / Outline',
              'Secondary Public Opinion Surge: Shift from the Incident Itself to Procedural Legitimacy',
              'Behavioral Differentiation of Multiple Agents: Media Rationalization, Platform Risk Control, Public Polarization',
              'University Governance Enters the Era of Reversible Decisions: Reputation Risk and Decision Transparency Become Core Variables',
              'Complete'].asMap().entries.map((e) => _SectionRow(
                section: ReportSection(
                  id: '${e.key}',
                  title: e.value,
                  status: done ? 'complete' : e.key == 0 ? 'complete' : 'pending',
                  content: '',
                ))),

          if (done) ...[
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => context.read<AppProvider>().setStep(AppStep.interaction),
              style: ElevatedButton.styleFrom(
                backgroundColor: MFColors.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Go to Interaction →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ],

          const SizedBox(height: 20),

          // Report trace log
          _traceSection('REPORT STARTED', [
            _traceKV('Simulation', p.project?.simulationId ?? 'sim_demo'),
            _traceKV('Requirement', p.reportRequirement.isNotEmpty
              ? p.reportRequirement : 'What would be the public opinion trend if...'),
          ]),

          if (sections.isNotEmpty || done) ...[
            _traceSection('PLANNING', [
              _tracePill('Starting to plan report outline', MFColors.bgSecond),
            ]),
            _traceSection('PLAN COMPLETE', [
              _tracePill('Outline planning complete', const Color(0xFFEFFCF4)),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: MFColors.border), borderRadius: BorderRadius.circular(4)),
                child: Text('${sections.isEmpty ? 3 : sections.length} sections planned',
                  style: const TextStyle(fontSize: 11, color: MFColors.textSecond)),
              ),
            ]),
          ],
        ]),
      )),
    ]);
  }

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(border: Border.all(color: MFColors.border), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: const TextStyle(fontSize: 9, color: MFColors.textSecond)));

  Widget _traceSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5, right: 10),
          decoration: const BoxDecoration(color: MFColors.textMuted, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MFColors.textPrimary)),
          const SizedBox(height: 6),
          ...children,
        ])),
      ]),
    );
  }

  Widget _traceKV(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(k, style: const TextStyle(fontSize: 10, color: MFColors.textMuted))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 10, color: MFColors.textSecond))),
    ]),
  );

  Widget _tracePill(String label, Color bg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      border: Border.all(color: MFColors.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11, color: MFColors.textPrimary)));
}

class _SectionRow extends StatelessWidget {
  final ReportSection section;
  const _SectionRow({required this.section});

  @override
  Widget build(BuildContext context) {
    final isDone = section.status == 'complete';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: isDone ? MFColors.accentGreen.withOpacity(0.3) : MFColors.border),
        borderRadius: BorderRadius.circular(6),
        color: isDone ? MFColors.accentGreen.withOpacity(0.03) : MFColors.bg,
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: isDone ? MFColors.accentGreen : MFColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(section.title,
          style: TextStyle(fontSize: 12, color: isDone ? MFColors.textPrimary : MFColors.textSecond))),
      ]),
    );
  }
}
