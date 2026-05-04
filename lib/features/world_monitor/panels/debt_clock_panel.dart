// lib/panels/debt_clock_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wm_theme.dart';
import '../widgets/floating_panel.dart';
import '../services/dashboard_provider.dart';

class DebtClockPanel extends StatefulWidget {
  const DebtClockPanel({super.key});
  @override State<DebtClockPanel> createState() => _DebtClockPanelState();
}

class _DebtClockPanelState extends State<DebtClockPanel> {
  String _selected = 'United States';

  static const _debtBase = {
    'United States': 36.2, 'Japan': 10.1, 'China': 15.3, 'Germany': 3.1,
    'France': 3.4, 'United Kingdom': 3.5, 'Italy': 3.2, 'India': 3.7,
    'Canada': 1.8, 'Brazil': 1.9, 'Australia': 0.8, 'South Korea': 0.7,
    'Spain': 1.5, 'Mexico': 0.8, 'Russia': 0.4,
  };
  static const _debtPerSec = {
    'United States': 52000.0, 'Japan': 12000.0, 'China': 18000.0, 'Germany': 4000.0,
    'France': 5000.0, 'United Kingdom': 5200.0, 'Italy': 4800.0, 'India': 6000.0,
    'Canada': 2500.0, 'Brazil': 3000.0, 'Australia': 1200.0, 'South Korea': 1000.0,
    'Spain': 2200.0, 'Mexico': 1100.0, 'Russia': 500.0,
  };
  static const _gdp = {
    'United States': 28.8, 'Japan': 4.4, 'China': 18.5, 'Germany': 4.5,
    'France': 3.1, 'United Kingdom': 3.2, 'Italy': 2.2, 'India': 3.9,
    'Canada': 2.1, 'Brazil': 2.2, 'Australia': 1.7, 'South Korea': 1.7,
    'Spain': 1.6, 'Mexico': 1.4, 'Russia': 2.1,
  };
  static const _population = {
    'United States': 337.0, 'Japan': 123.0, 'China': 1412.0, 'Germany': 84.0,
    'France': 68.0, 'United Kingdom': 68.0, 'Italy': 59.0, 'India': 1440.0,
    'Canada': 40.0, 'Brazil': 215.0, 'Australia': 26.0, 'South Korea': 51.0,
    'Spain': 47.0, 'Mexico': 130.0, 'Russia': 144.0,
  };

  double _currentDebt(DashboardProvider p) {
    final base   = (_debtBase[_selected] ?? 1.0) * 1e12;
    final perSec = _debtPerSec[_selected] ?? 1000.0;
    final now    = p.now;
    final secs   = now.hour * 3600 + now.minute * 60 + now.second;
    return base + secs * perSec;
  }

  String _fmt(double n) {
    if (n >= 1e9) return '${(n/1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '${(n/1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n/1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  String _formatFull(double n) => '\$${n.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final debt     = _currentDebt(provider);
    final gdp      = (_gdp[_selected] ?? 1.0) * 1e12;
    final pop      = (_population[_selected] ?? 1.0) * 1e6;
    final ratio    = debt / gdp;
    final perCit   = debt / pop;
    final perSec   = _debtPerSec[_selected] ?? 0.0;

    return GridPanel(
      title: 'NATIONAL DEBT CLOCK',
      isLive: true,
      onClose: () => context.read<DashboardProvider>().togglePanel(PanelId.debtClock),
      headerActions: [
        const Icon(Icons.account_balance, color: WMColors.textMuted, size: 13),
      ],
      child: Column(children: [
        // Country dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: WMColors.border))),
          child: DropdownButton<String>(
            value: _selected, isExpanded: true, isDense: true,
            dropdownColor: WMColors.bgPanel,
            style: const TextStyle(color: WMColors.textPrimary, fontSize: 10),
            underline: const SizedBox(),
            items: _debtBase.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
            onChanged: (v) { if (v != null) setState(() => _selected = v); },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Main counter
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WMColors.bgHeader,
                  border: Border.all(color: WMColors.critBorder),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Column(children: [
                  const Text('NATIONAL DEBT', style: TextStyle(color: WMColors.textSecond, fontSize: 8, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(_formatFull(debt), style: const TextStyle(
                      color: WMColors.accentRed, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 4),
                  Text('\$${(debt/1e12).toStringAsFixed(4)} Trillion',
                    style: const TextStyle(color: WMColors.textSecond, fontSize: 10)),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _StatTile(label: 'PER SECOND', value: '\$${_fmt(perSec)}')),
                const SizedBox(width: 6),
                Expanded(child: _StatTile(label: 'PER CITIZEN', value: '\$${_fmt(perCit)}')),
                const SizedBox(width: 6),
                Expanded(child: _StatTile(label: 'DEBT/GDP',
                  value: '${(ratio*100).toStringAsFixed(1)}%',
                  color: ratio > 1.2 ? WMColors.accentRed : ratio > 0.8 ? WMColors.accentOrange : WMColors.accentYellow)),
              ]),
              const SizedBox(height: 10),
              // Debt/GDP bar
              const Text('DEBT-TO-GDP RATIO', style: TextStyle(color: WMColors.textSecond, fontSize: 8, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
                value: (ratio / 2.0).clamp(0.0, 1.0), backgroundColor: WMColors.border,
                valueColor: AlwaysStoppedAnimation(ratio > 1.2 ? WMColors.accentRed : WMColors.accentOrange),
                minHeight: 8,
              )),
              const SizedBox(height: 14),
              const Text('GLOBAL COMPARISON', style: TextStyle(color: WMColors.textSecond, fontSize: 8, letterSpacing: 1.0)),
              const SizedBox(height: 6),
              ..._debtBase.entries.map((e) {
                final isSelected = e.key == _selected;
                final secs = (provider.now.hour * 3600 + provider.now.minute * 60 + provider.now.second).toDouble();
                final cur  = e.value * 1e12 + secs * (_debtPerSec[e.key] ?? 0);
                return GestureDetector(
                  onTap: () => setState(() => _selected = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? WMColors.accentGreen.withOpacity(0.08) : Colors.transparent,
                      border: Border(bottom: BorderSide(color: WMColors.border.withOpacity(0.3))),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(e.key, style: TextStyle(
                        color: isSelected ? WMColors.accentGreen : WMColors.textSecond, fontSize: 9))),
                      Text('\$${(cur/1e12).toStringAsFixed(2)}T', style: TextStyle(
                        color: isSelected ? WMColors.accentGreen : WMColors.textMuted,
                        fontSize: 9, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile({required this.label, required this.value, this.color = WMColors.accentOrange});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(color: WMColors.bgHeader, border: Border.all(color: WMColors.border), borderRadius: BorderRadius.circular(2)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: WMColors.textMuted, fontSize: 7, letterSpacing: 0.8)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    ]),
  );
}
