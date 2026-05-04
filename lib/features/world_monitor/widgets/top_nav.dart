// lib/widgets/top_nav.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../wm_theme.dart';
import '../services/dashboard_provider.dart';

class TopNav extends StatelessWidget {
  const TopNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: WMColors.bgHeader,
        border: Border(bottom: BorderSide(color: WMColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Globe icon
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: WMColors.accentGreen.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: WMColors.accentGreen.withOpacity(0.5)),
              ),
              child: const Icon(Icons.public, color: WMColors.accentGreen, size: 14),
            ),
            const SizedBox(width: 8),
            // Map variant tabs
            ..._buildVariantTabs(provider),
            const SizedBox(width: 12),
            // Nav icons
            _NavIcon(icon: Icons.article_outlined, onTap: () {}),
            _NavIcon(icon: Icons.show_chart, onTap: () {}),
            _NavIcon(icon: Icons.bolt, onTap: () {}),
            _NavIcon(icon: Icons.radio_button_on, onTap: () {}),
            const SizedBox(width: 10),
            const Text('MONITOR', style: TextStyle(color: WMColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(width: 6),
            const Text('v2.6.7', style: TextStyle(color: WMColors.textMuted, fontSize: 8)),
            const SizedBox(width: 10),
            _LiveBadge(),
            const SizedBox(width: 10),
            // Region
            _RegionSelector(),
            const SizedBox(width: 10),
            _DefconBadge(level: provider.defconLevel),
            const SizedBox(width: 20),
            // Clock
            Text(
              DateFormat('EEE, dd MMM yyyy HH:mm:ss').format(provider.now).toUpperCase() + ' UTC',
              style: const TextStyle(color: WMColors.textSecond, fontSize: 8, letterSpacing: 0.5),
            ),
            const SizedBox(width: 20),
            // Right side
            _NavIcon(icon: Icons.search, onTap: () {}),
            _NavIcon(icon: Icons.link, onTap: () {}),
            _NavIcon(icon: Icons.refresh, onTap: () {}),
            _NavIcon(icon: Icons.settings, onTap: provider.toggleSettings),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVariantTabs(DashboardProvider provider) {
    return MapVariant.values.map((v) => GestureDetector(
      onTap: () => provider.setMapVariant(v),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: provider.mapVariant == v ? v.accent.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: provider.mapVariant == v ? v.accent : WMColors.borderLight,
            width: provider.mapVariant == v ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          v.label,
          style: TextStyle(
            color: provider.mapVariant == v ? v.accent : WMColors.textMuted,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    )).toList();
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Icon(icon, color: WMColors.textMuted, size: 16),
    ),
  );
}

class _LiveBadge extends StatefulWidget {
  @override State<_LiveBadge> createState() => _LiveBadgeState();
}
class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(duration: const Duration(seconds: 1), vsync: this)..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Row(children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: WMColors.accentGreen.withOpacity(0.4 + 0.6 * _c.value),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: WMColors.accentGreen.withOpacity(0.3 * _c.value), blurRadius: 4)],
        ),
      ),
      const SizedBox(width: 5),
      Text('LIVE', style: TextStyle(color: WMColors.accentGreen.withOpacity(0.6 + 0.4 * _c.value), fontSize: 8, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _RegionSelector extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(border: Border.all(color: WMColors.border), borderRadius: BorderRadius.circular(2)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.language, color: WMColors.textMuted, size: 12),
      SizedBox(width: 4),
      Text('Global', style: TextStyle(color: WMColors.textSecond, fontSize: 8)),
      SizedBox(width: 4),
      Icon(Icons.keyboard_arrow_down, color: WMColors.textMuted, size: 12),
    ]),
  );
}

class _DefconBadge extends StatelessWidget {
  final int level;
  const _DefconBadge({required this.level});

  Color get _color {
    switch (level) {
      case 1: return WMColors.accentRed;
      case 2: return WMColors.accentRed;
      case 3: return WMColors.accentOrange;
      case 4: return WMColors.accentYellow;
      default: return WMColors.accentGreen;
    }
  }

  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.15),
      border: Border.all(color: _color.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.arrow_back_ios, color: _color, size: 7),
      const SizedBox(width: 3),
      Text('DEFCON $level', style: TextStyle(color: _color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      const SizedBox(width: 5),
      Text('1%', style: TextStyle(color: _color.withOpacity(0.6), fontSize: 7)),
    ]),
  );
}
