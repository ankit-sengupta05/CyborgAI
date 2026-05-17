/// World Monitor — Full Dashboard
/// This screen wraps the complete wm2 intelligence dashboard inside Cyborg's shell.
/// It uses the wm2 DashboardProvider + DataService (via provider package) for live
/// geopolitical data, map, webcams, and intelligence panels — while also connecting
/// to Cyborg's backend for system metrics and AI briefing via Riverpod.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_provider.dart';
import '../services/data_service.dart';
import '../panels/map_panel.dart';
import '../panels/live_news_panel.dart';
import '../panels/live_webcams_panel.dart';
import '../panels/intelligence_panels.dart';
import '../panels/debt_clock_panel.dart';
import '../widgets/top_nav.dart';
import '../wm_theme.dart';
import 'settings_overlay.dart';

class WorldMonitorScreen extends StatefulWidget {
  const WorldMonitorScreen({super.key});
  @override
  State<WorldMonitorScreen> createState() => _WorldMonitorScreenState();
}

class _WorldMonitorScreenState extends State<WorldMonitorScreen> {
  double _sheetH = 320;
  double _dragStartSheetH = 320;
  bool _layoutDone = false;

  static const double _minSheet = 28.0;

  double get _screenH {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - 42;
  }

  double get _maxSheet => _screenH - 60;

  void _onDragStart(DragStartDetails d) => _dragStartSheetH = _sheetH;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(
        () => _sheetH = (_sheetH - d.delta.dy).clamp(_minSheet, _maxSheet));
  }

  void _onDragEnd(DragEndDetails d) {
    final vel = d.primaryVelocity ?? 0;
    double target;
    final snapCollapsed = _minSheet;
    final snapHalf = _screenH * 0.38;
    final snapFull = _maxSheet;
    if (vel > 500) {
      target = snapCollapsed;
    } else if (vel < -500) {
      target = snapFull;
    } else {
      final dists = {
        snapCollapsed: (_sheetH - snapCollapsed).abs(),
        snapHalf: (_sheetH - snapHalf).abs(),
        snapFull: (_sheetH - snapFull).abs(),
      };
      target = dists.entries.reduce((a, b) => a.value < b.value ? a : b).key;
    }
    _animateTo(target);
  }

  void _animateTo(double target) {
    final start = _sheetH;
    final diff = target - start;
    if (diff.abs() < 1) return;
    const steps = 18;
    int step = 0;
    void tick() {
      if (!mounted) return;
      step++;
      final t = step / steps;
      final ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
      setState(() => _sheetH = start + diff * ease);
      if (step < steps) {
        Future.delayed(const Duration(milliseconds: 14), tick);
      } else {
        setState(() => _sheetH = target);
      }
    }

    Future.delayed(const Duration(milliseconds: 14), tick);
  }

  Widget _buildPanelWidget(PanelId id) {
    switch (id) {
      case PanelId.liveNews:
        return const LiveNewsPanel();
      case PanelId.liveWebcams:
        return const LiveWebcamsPanel();
      case PanelId.aiInsights:
        return const AiInsightsPanel();
      case PanelId.aiForecasts:
        return const AiForecastsPanel();
      case PanelId.countryInstability:
        return const CountryInstabilityPanel();
      case PanelId.strategicRisk:
        return const StrategicRiskPanel();
      case PanelId.aiStrategicPosture:
        return const AiStrategicPosturePanel();
      case PanelId.debtClock:
        return const DebtClockPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => DataService()),
      ],
      child: _WorldMonitorBody(
        buildPanelWidget: _buildPanelWidget,
        sheetH: _sheetH,
        layoutDone: _layoutDone,
        minSheet: _minSheet,
        maxSheet: _maxSheet,
        onLayoutDone: (h) => setState(() {
          _sheetH = h;
          _layoutDone = true;
        }),
        onDragStart: _onDragStart,
        onDragUpdate: _onDragUpdate,
        onDragEnd: _onDragEnd,
        onSnapCollapsed: () => _animateTo(_minSheet),
        onSnapHalf: () => _animateTo(_screenH * 0.38),
        onSnapFull: () => _animateTo(_maxSheet),
      ),
    );
  }
}

class _WorldMonitorBody extends StatelessWidget {
  final Widget Function(PanelId) buildPanelWidget;
  final double sheetH, minSheet, maxSheet;
  final bool layoutDone;
  final void Function(double) onLayoutDone;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onSnapCollapsed, onSnapHalf, onSnapFull;

  const _WorldMonitorBody({
    required this.buildPanelWidget,
    required this.sheetH,
    required this.layoutDone,
    required this.minSheet,
    required this.maxSheet,
    required this.onLayoutDone,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSnapCollapsed,
    required this.onSnapHalf,
    required this.onSnapFull,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    return Scaffold(
      backgroundColor: WMColors.bgPrimary,
      body: LayoutBuilder(builder: (context, constraints) {
        if (!layoutDone && constraints.maxHeight > 100) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onLayoutDone(constraints.maxHeight * 0.38);
          });
        }
        final availH = constraints.maxHeight - 42;
        final safeSheet = sheetH.clamp(minSheet, availH - 60.0);
        final safeMap = (availH - safeSheet).clamp(60.0, availH - minSheet);

        return Stack(children: [
          Column(children: [
            const TopNav(),
            SizedBox(
              height: availH,
              child: Column(children: [
                SizedBox(height: safeMap, child: const MapPanel()),
                SizedBox(
                  height: safeSheet,
                  child: Column(children: [
                    _DragHandle(
                      sheetH: safeSheet,
                      maxSheet: availH - 60,
                      provider: provider,
                      onDragStart: onDragStart,
                      onDragUpdate: onDragUpdate,
                      onDragEnd: onDragEnd,
                      onSnapCollapsed: onSnapCollapsed,
                      onSnapHalf: onSnapHalf,
                      onSnapFull: onSnapFull,
                    ),
                    if (safeSheet > 50)
                      Expanded(
                        child: _PanelGrid(
                          provider: provider,
                          buildPanel: buildPanelWidget,
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ]),
          if (provider.settingsOpen) const SettingsOverlay(),
        ]);
      }),
    );
  }
}

// ── Drag Handle (copied from wm2 dashboard_screen) ────────────────────────────
class _DragHandle extends StatelessWidget {
  final double sheetH, maxSheet;
  final DashboardProvider provider;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onSnapCollapsed, onSnapHalf, onSnapFull;

  const _DragHandle({
    required this.sheetH,
    required this.maxSheet,
    required this.provider,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSnapCollapsed,
    required this.onSnapHalf,
    required this.onSnapFull,
  });

  bool get _isCollapsed => sheetH < 40;
  bool get _isFull => sheetH > maxSheet * 0.85;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: WMColors.bgHeader,
          border: Border(
            top: BorderSide(
                color: WMColors.accentGreen.withOpacity(0.35), width: 1),
            bottom: BorderSide(color: WMColors.border),
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (_isCollapsed)
                onSnapHalf();
              else if (!_isFull)
                onSnapFull();
              else
                onSnapCollapsed();
            },
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: WMColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: provider.panels
                    .map((p) => _PChip(
                          label: _short(p.title),
                          isOn: p.visible,
                          onTap: () => provider.togglePanel(p.id),
                        ))
                    .toList(),
              ),
            ),
          ),
          GestureDetector(
            onTap: _isCollapsed
                ? onSnapHalf
                : (_isFull ? onSnapCollapsed : onSnapFull),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                _isFull ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                color: WMColors.textMuted,
                size: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: provider.toggleSettings,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: WMColors.borderLight),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: WMColors.textMuted, size: 10),
                SizedBox(width: 3),
                Text('MANAGE PANELS',
                    style: TextStyle(
                        color: WMColors.textMuted,
                        fontSize: 7,
                        letterSpacing: 0.7)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _short(String t) {
    const m = {
      'LIVE NEWS': 'LIVE NEWS',
      'LIVE WEBCAMS': 'WEBCAMS',
      'AI INSIGHTS': 'AI INSIGHTS',
      'AI FORECASTS': 'FORECASTS',
      'COUNTRY INSTABILITY': 'INSTABILITY',
      'STRATEGIC RISK': 'RISK',
      'AI STRATEGIC POSTURE': 'POSTURE',
      'NATIONAL DEBT CLOCK': 'DEBT CLOCK',
    };
    return m[t] ?? t;
  }
}

class _PChip extends StatelessWidget {
  final String label;
  final bool isOn;
  final VoidCallback onTap;
  const _PChip({required this.label, required this.isOn, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 5, top: 5, bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: isOn
                ? WMColors.accentGreen.withOpacity(0.12)
                : Colors.transparent,
            border: Border.all(
                color: isOn
                    ? WMColors.accentGreen.withOpacity(0.6)
                    : WMColors.borderLight),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(label,
              style: TextStyle(
                color: isOn ? WMColors.accentGreen : WMColors.textMuted,
                fontSize: 7,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              )),
        ),
      );
}

// ── Panel Grid ────────────────────────────────────────────────────────────────
class _PanelGrid extends StatefulWidget {
  final DashboardProvider provider;
  final Widget Function(PanelId) buildPanel;
  const _PanelGrid({required this.provider, required this.buildPanel});
  @override
  State<_PanelGrid> createState() => _PanelGridState();
}

class _PanelGridState extends State<_PanelGrid> {
  int? _draggingIdx;

  @override
  Widget build(BuildContext context) {
    final visible = widget.provider.visiblePanels;
    if (visible.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.dashboard_outlined,
            color: WMColors.textMuted, size: 32),
        const SizedBox(height: 10),
        const Text('No panels visible',
            style: TextStyle(color: WMColors.textMuted, fontSize: 11)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.provider.toggleSettings,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: WMColors.accentGreen),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text('Manage Panels',
                style: TextStyle(color: WMColors.accentGreen, fontSize: 10)),
          ),
        ),
      ]));
    }

    final w = MediaQuery.of(context).size.width;
    final cols = w > 1400
        ? 4
        : w > 900
            ? 3
            : w > 600
                ? 2
                : 1;
    const rowH = 300.0;

    final rows = <Widget>[];
    for (int r = 0; r * cols < visible.length; r++) {
      final rowPanels =
          visible.sublist(r * cols, ((r + 1) * cols).clamp(0, visible.length));
      rows.add(SizedBox(
        height: rowH,
        child: Row(children: [
          ...rowPanels.asMap().entries.map((e) {
            final idx = r * cols + e.key;
            return Expanded(
                child: Padding(
              padding: const EdgeInsets.all(2),
              child: DragTarget<int>(
                onWillAcceptWithDetails: (d) => d.data != idx,
                onAcceptWithDetails: (d) =>
                    widget.provider.reorderPanels(d.data, idx),
                builder: (ctx, candidates, _) => Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: candidates.isNotEmpty
                              ? WMColors.accentGreen
                              : Colors.transparent,
                          width: 2)),
                  child: Draggable<int>(
                    data: idx,
                    onDragStarted: () => setState(() => _draggingIdx = idx),
                    onDragEnd: (_) => setState(() => _draggingIdx = null),
                    feedback: Material(
                        color: Colors.transparent,
                        child: Opacity(
                            opacity: 0.72,
                            child: SizedBox(
                                width: 260,
                                height: 220,
                                child: MultiProvider(
                                  providers: [
                                    ChangeNotifierProvider.value(value: widget.provider),
                                    ChangeNotifierProvider.value(value: context.read<DataService>()),
                                  ],
                                  child: widget.buildPanel(e.value.id),
                                )))),
                    childWhenDragging: Container(
                        decoration: BoxDecoration(
                            color: WMColors.accentGreen.withOpacity(0.04),
                            border: Border.all(
                                color: WMColors.accentGreen.withOpacity(0.3))),
                        child: const Center(
                            child: Icon(Icons.add_box_outlined,
                                color: WMColors.accentGreen, size: 24))),
                    child: widget.buildPanel(e.value.id),
                  ),
                ),
              ),
            ));
          }),
          ...List.generate(
              cols - rowPanels.length,
              (_) => Expanded(
                      child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (_) => true,
                      onAcceptWithDetails: (_) {},
                      builder: (ctx, candidates, _) => GestureDetector(
                        onTap: widget.provider.toggleSettings,
                        child: Container(
                          decoration: BoxDecoration(
                              color: candidates.isNotEmpty
                                  ? WMColors.accentGreen.withOpacity(0.05)
                                  : WMColors.bgPanel.withOpacity(0.4),
                              border: Border.all(
                                  color: candidates.isNotEmpty
                                      ? WMColors.accentGreen
                                      : WMColors.border.withOpacity(0.4))),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: candidates.isNotEmpty
                                        ? WMColors.accentGreen
                                        : WMColors.textMuted,
                                    size: 20),
                                const SizedBox(height: 6),
                                Text('ADD PANEL',
                                    style: TextStyle(
                                        color: candidates.isNotEmpty
                                            ? WMColors.accentGreen
                                            : WMColors.textMuted,
                                        fontSize: 8,
                                        letterSpacing: 1.2)),
                              ]),
                        ),
                      ),
                    ),
                  ))),
        ]),
      ));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: rows),
    );
  }
}
