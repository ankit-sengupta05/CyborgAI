import 'package:flutter/material.dart';
import '../theme/paperclip_theme.dart';
import '../models/models.dart';

// ── StatusIcon ─────────────────────────────────────────────────────────────
class PcStatusIcon extends StatelessWidget {
  final IssueStatus status;
  final double size;

  const PcStatusIcon({super.key, required this.status, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      IssueStatus.open => Icon(Icons.circle_outlined,
          size: size, color: PaperclipTheme.statusOpen),
      IssueStatus.inProgress => SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            value: 0.6,
            color: PaperclipTheme.statusInProgress,
            backgroundColor: PaperclipTheme.statusInProgress.withValues(alpha: 0.2),
          ),
        ),
      IssueStatus.done =>
        Icon(Icons.check_circle_rounded, size: size, color: PaperclipTheme.statusDone),
      IssueStatus.cancelled =>
        Icon(Icons.cancel_rounded, size: size, color: PaperclipTheme.statusCancelled),
    };
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────
class PcBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const PcBadge({super.key, required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? PaperclipTheme.accentGreen.withValues(alpha: 0.15);
    final fg = textColor ?? PaperclipTheme.accentGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Metric Card ────────────────────────────────────────────────────────────
class PcMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const PcMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? PaperclipTheme.accentGreen;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(PaperclipTheme.radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.labelMedium),
          ]),
          const SizedBox(height: 10),
          Text(value, style: theme.textTheme.headlineMedium),
        ],
      ),
    );
  }
}

// ── Skeleton loader ────────────────────────────────────────────────────────
class PcSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const PcSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  State<PcSkeleton> createState() => _PcSkeletonState();
}

class _PcSkeletonState extends State<PcSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: theme.dividerColor.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class PcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PcEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAction = action ?? (actionLabel != null && onAction != null
        ? ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 16),
            label: Text(actionLabel!),
          )
        : null);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PaperclipTheme.accentGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PaperclipTheme.accentGreen.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, size: 28, color: PaperclipTheme.accentGreen.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
            if (effectiveAction != null) ...[
              const SizedBox(height: 20),
              effectiveAction,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Page Header ───────────────────────────────────────────────────────────────
/// Standardised top-bar used by most full-page screens in the app.
/// Renders a bordered header row with an optional [actions] list on the right.
class PcPageHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> actions;

  const PcPageHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

// ── Section header (sidebar) ────────────────────────────────────────────────
class PcSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const PcSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                letterSpacing: 0.8,
              )),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Connection badge ───────────────────────────────────────────────────────
class PcConnectionBadge extends StatelessWidget {
  final bool connected;
  final String? label;

  const PcConnectionBadge({super.key, required this.connected, this.label});

  @override
  Widget build(BuildContext context) {
    final color = connected ? PaperclipTheme.statusDone : PaperclipTheme.statusBlocked;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: connected
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                : null,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(label!,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ],
    );
  }
}

// ── Glowing accent card ──────────────────────────────────────────────────────
class PcAccentCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsets? padding;

  const PcAccentCard({
    super.key,
    required this.color,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(PaperclipTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

// ── Section card (settings-style) ────────────────────────────────────────────
class PcSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const PcSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 0.9,
                )),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(PaperclipTheme.radius),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.asMap().entries.map((entry) {
              final isLast = entry.key == children.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast)
                    Divider(height: 1, thickness: 1, color: theme.dividerColor),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
