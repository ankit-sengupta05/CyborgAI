// lib/widgets/floating_panel.dart
// Grid-based panel with header, no floating positioning
import 'package:flutter/material.dart';
import '../wm_theme.dart';

class GridPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? headerActions;
  final int? count;
  final Color? countColor;
  final bool isLive;
  final VoidCallback? onClose;
  final EdgeInsets padding;

  const GridPanel({
    super.key,
    required this.title,
    required this.child,
    this.headerActions,
    this.count,
    this.countColor,
    this.isLive = false,
    this.onClose,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WMColors.bgPanel,
        border: Border.all(color: WMColors.border, width: 1),
      ),
      child: Column(
        children: [
          _PanelHeader(
            title: title,
            count: count,
            countColor: countColor,
            isLive: isLive,
            actions: headerActions,
            onClose: onClose,
          ),
          Expanded(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Color? countColor;
  final bool isLive;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  const _PanelHeader({
    required this.title,
    this.count,
    this.countColor,
    this.isLive = false,
    this.actions,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: WMColors.bgHeader,
        border: Border(bottom: BorderSide(color: WMColors.border)),
      ),
      child: Row(
        children: [
          // Drag handle icon (visual only in grid mode)
          const Icon(Icons.drag_indicator, color: WMColors.textMuted, size: 12),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(
            color: WMColors.textPrimary, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1.2,
          )),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: (countColor ?? WMColors.accentRed).withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text('$count', style: TextStyle(
                color: countColor ?? WMColors.accentRed,
                fontSize: 8, fontWeight: FontWeight.bold,
              )),
            ),
          ],
          if (isLive) ...[
            const SizedBox(width: 8),
            const _LivePulse(),
          ],
          const Spacer(),
          if (actions != null) ...actions!,
          const SizedBox(width: 4),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: WMColors.textMuted, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse();
  @override State<_LivePulse> createState() => _LivePulseState();
}
class _LivePulseState extends State<_LivePulse> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(duration: const Duration(seconds: 1), vsync: this)..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Row(children: [
      Container(width: 6, height: 6,
        decoration: BoxDecoration(
          color: WMColors.accentRed.withOpacity(0.4 + 0.6 * _c.value),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: WMColors.accentRed.withOpacity(0.3 * _c.value), blurRadius: 4)],
        )),
      const SizedBox(width: 4),
      Text('LIVE', style: TextStyle(
        color: WMColors.accentRed.withOpacity(0.5 + 0.5 * _c.value),
        fontSize: 8, fontWeight: FontWeight.bold,
      )),
    ]),
  );
}

class WMBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;
  final double fontSize;

  const WMBtn({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? WMColors.accentGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          border: Border.all(color: isActive ? color : WMColors.borderLight),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label, style: TextStyle(
          color: isActive ? Colors.black : WMColors.textSecond,
          fontSize: fontSize, fontWeight: FontWeight.bold, letterSpacing: 0.5,
        )),
      ),
    );
  }
}
