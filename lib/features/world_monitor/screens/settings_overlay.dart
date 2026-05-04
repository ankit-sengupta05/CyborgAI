// lib/screens/settings_overlay.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wm_theme.dart';
import '../services/dashboard_provider.dart';

class SettingsOverlay extends StatefulWidget {
  const SettingsOverlay({super.key});
  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  String _tab = 'PANELS';
  static const _tabs = ['SETTINGS', 'PANELS', 'SOURCES', 'NOTIFICATIONS'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    return GestureDetector(
      onTap: provider.toggleSettings,
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 640,
              height: 520,
              decoration: BoxDecoration(
                color: WMColors.bgPanel,
                border: Border.all(color: WMColors.borderLight),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(children: [
                _header(provider),
                _tabs_row(),
                Expanded(child: _content(provider)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(DashboardProvider p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: WMColors.border))),
        child: Row(children: [
          const Text('SETTINGS',
              style: TextStyle(
                  color: WMColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const Spacer(),
          GestureDetector(
              onTap: p.toggleSettings,
              child:
                  const Icon(Icons.close, color: WMColors.textMuted, size: 18)),
        ]),
      );

  Widget _tabs_row() => Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: WMColors.border))),
        child: Row(
            children: _tabs
                .map((t) => GestureDetector(
                      onTap: () => setState(() => _tab = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: _tab == t
                                        ? WMColors.accentGreen
                                        : Colors.transparent,
                                    width: 2))),
                        child: Text(t,
                            style: TextStyle(
                              color: _tab == t
                                  ? WMColors.textPrimary
                                  : WMColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            )),
                      ),
                    ))
                .toList()),
      );

  Widget _content(DashboardProvider p) {
    if (_tab != 'PANELS')
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_outline, color: WMColors.textMuted, size: 32),
        const SizedBox(height: 12),
        Text('$_tab requires Pro subscription',
            style: const TextStyle(color: WMColors.textMuted, fontSize: 11)),
      ]));

    final panels = p.panels;
    return Column(children: [
      // Filter row
      Padding(
        padding: const EdgeInsets.all(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: [
            'ALL',
            'CORE',
            'INTELLIGENCE',
            'CORRELATION',
            'REGIONAL NEWS',
            'MARKETS & FINANCE'
          ]
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              border: Border.all(color: WMColors.borderLight),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(f,
                              style: const TextStyle(
                                  color: WMColors.textSecond, fontSize: 9)),
                        ),
                      ))
                  .toList()),
        ),
      ),
      // Panel grid
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 3.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: panels.map((panel) {
              final isOn = panel.visible;
              return GestureDetector(
                onTap: () => p.togglePanel(panel.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOn
                        ? WMColors.accentGreen.withOpacity(0.08)
                        : WMColors.bgHeader,
                    border: Border.all(
                        color: isOn
                            ? WMColors.accentGreen.withOpacity(0.5)
                            : WMColors.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(children: [
                    Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: isOn ? WMColors.accentGreen : Colors.transparent,
                        border: Border.all(
                            color: isOn
                                ? WMColors.accentGreen
                                : WMColors.borderLight),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: isOn
                          ? const Icon(Icons.check,
                              size: 9, color: Colors.black)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(panel.title,
                            style: TextStyle(
                              color: isOn
                                  ? WMColors.textPrimary
                                  : WMColors.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ]);
  }
}
