import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/paperclip_theme.dart';
import '../widgets/shared_widgets.dart';

enum AppRoute {
  dashboard,
  issues,
  goals,
  agents,
  projects,
  routines,
  approvals,
  costs,
  activity,
  workspaces,
  org,
  settings,
  lmStudio,
  graph,
  chat,
  vault,
  ingest,
  worldMonitor,
  mirofish,
  gsd,
  education,
  health,
  codeFlow,
  github,
  skills,
  deviceManager,
  modelsLibrary,
  voiceAssistant,
  voiceCallAgent,
}

class PcSidebar extends StatelessWidget {
  final AppRoute currentRoute;
  final void Function(AppRoute) onNavigate;

  const PcSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final company = state.selectedCompany;
    final isDark = theme.brightness == Brightness.dark;
    final sidebarBg = isDark ? PaperclipTheme.sidebarDark : PaperclipTheme.sidebarLight;

    return Container(
      width: PaperclipTheme.sidebarWidth,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          // ── Top bar: workspace + company picker ──────────────────────────
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                // App logo / brand mark
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: PaperclipTheme.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PaperclipTheme.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.memory, size: 13, color: PaperclipTheme.accentGreen),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: company != null
                      ? _CompanyMenu(state: state)
                      : Text('Cyborg AGI',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: 0.2,
                          )),
                ),
                _SidebarIconBtn(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onTap: () => onNavigate(AppRoute.issues),
                ),
                _SidebarIconBtn(
                  icon: Icons.add,
                  tooltip: 'New Issue',
                  onTap: () => _showNewIssueDialog(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              children: [
                // ── Main nav ───────────────────────────────────────────────
                _NavGroup(children: [
                  _NavItem(
                    label: 'Dashboard',
                    icon: Icons.grid_view_rounded,
                    selected: currentRoute == AppRoute.dashboard,
                    onTap: () => onNavigate(AppRoute.dashboard),
                  ),
                  _NavItem(
                    label: 'Inbox',
                    icon: Icons.inbox_rounded,
                    selected: false,
                    onTap: () => onNavigate(AppRoute.issues),
                  ),
                  _NavItem(
                    label: 'Issues',
                    icon: Icons.circle_outlined,
                    selected: currentRoute == AppRoute.issues,
                    onTap: () => onNavigate(AppRoute.issues),
                  ),
                  _NavItem(
                    label: 'Goals',
                    icon: Icons.flag_rounded,
                    selected: currentRoute == AppRoute.goals,
                    onTap: () => onNavigate(AppRoute.goals),
                  ),
                  _NavItem(
                    label: 'Approvals',
                    icon: Icons.verified_outlined,
                    selected: currentRoute == AppRoute.approvals,
                    onTap: () => onNavigate(AppRoute.approvals),
                  ),
                  _NavItem(
                    label: 'Activity',
                    icon: Icons.timeline_rounded,
                    selected: currentRoute == AppRoute.activity,
                    onTap: () => onNavigate(AppRoute.activity),
                  ),
                  _NavItem(
                    label: 'Costs',
                    icon: Icons.paid_outlined,
                    selected: currentRoute == AppRoute.costs,
                    onTap: () => onNavigate(AppRoute.costs),
                  ),
                ]),

                const SizedBox(height: 4),
                const _SectionDivider(label: 'INTELLIGENCE'),

                _NavGroup(children: [
                  _NavItem(
                    label: 'AGI Chat',
                    icon: Icons.chat_bubble_rounded,
                    selected: currentRoute == AppRoute.chat,
                    onTap: () => onNavigate(AppRoute.chat),
                    accentColor: PaperclipTheme.accentGreen,
                  ),
                  _NavItem(
                    icon: Icons.phone_in_talk_rounded,
                    label: 'Call Agent',
                    selected: currentRoute == AppRoute.voiceCallAgent,
                    onTap: () => onNavigate(AppRoute.voiceCallAgent),
                    accentColor: const Color(0xFF6C63FF),
                  ),
                  _NavItem(
                    icon: Icons.mic_none_rounded,
                    label: 'Voice Assistant',
                    selected: currentRoute == AppRoute.voiceAssistant,
                    onTap: () => onNavigate(AppRoute.voiceAssistant),
                    accentColor: PaperclipTheme.accentCyan,
                  ),
                  _NavItem(
                    label: 'Knowledge Graph',
                    icon: Icons.hub_rounded,
                    selected: currentRoute == AppRoute.graph,
                    onTap: () => onNavigate(AppRoute.graph),
                    accentColor: PaperclipTheme.accentCyan,
                  ),
                  _NavItem(
                    label: 'Vault (Notes)',
                    icon: Icons.auto_stories_rounded,
                    selected: currentRoute == AppRoute.vault,
                    onTap: () => onNavigate(AppRoute.vault),
                  ),
                  _NavItem(
                    label: 'Ingest (Data)',
                    icon: Icons.upload_rounded,
                    selected: currentRoute == AppRoute.ingest,
                    onTap: () => onNavigate(AppRoute.ingest),
                  ),
                  _NavItem(
                    label: 'Skills & Tools',
                    icon: Icons.extension_rounded,
                    selected: currentRoute == AppRoute.skills,
                    onTap: () => onNavigate(AppRoute.skills),
                  ),
                  _NavItem(
                    label: 'GSD Engine',
                    icon: Icons.bolt_rounded,
                    selected: currentRoute == AppRoute.gsd,
                    onTap: () => onNavigate(AppRoute.gsd),
                    accentColor: PaperclipTheme.accentAmber,
                  ),
                ]),

                const SizedBox(height: 4),
                const _SectionDivider(label: 'SPECIALIZED'),

                _NavGroup(children: [
                  _NavItem(
                    label: 'World Monitor',
                    icon: Icons.public_rounded,
                    selected: currentRoute == AppRoute.worldMonitor,
                    onTap: () => onNavigate(AppRoute.worldMonitor),
                  ),
                  _NavItem(
                    label: 'MiroFish (Sim)',
                    icon: Icons.waves_rounded,
                    selected: currentRoute == AppRoute.mirofish,
                    onTap: () => onNavigate(AppRoute.mirofish),
                  ),
                  _NavItem(
                    label: 'Health AI',
                    icon: Icons.favorite_rounded,
                    selected: currentRoute == AppRoute.health,
                    onTap: () => onNavigate(AppRoute.health),
                    accentColor: PaperclipTheme.accentRed,
                  ),
                  _NavItem(
                    label: 'Education Hub',
                    icon: Icons.school_rounded,
                    selected: currentRoute == AppRoute.education,
                    onTap: () => onNavigate(AppRoute.education),
                  ),
                  _NavItem(
                    label: 'CodeFlow',
                    icon: Icons.code_rounded,
                    selected: currentRoute == AppRoute.codeFlow,
                    onTap: () => onNavigate(AppRoute.codeFlow),
                  ),
                  _NavItem(
                    label: 'GitHub Sync',
                    icon: Icons.terminal_rounded,
                    selected: currentRoute == AppRoute.github,
                    onTap: () => onNavigate(AppRoute.github),
                  ),
                ]),

                const SizedBox(height: 4),
                const _SectionDivider(label: 'OPERATIONS'),

                _NavGroup(children: [
                  _NavItem(
                    label: 'Projects',
                    icon: Icons.folder_rounded,
                    selected: currentRoute == AppRoute.projects,
                    onTap: () => onNavigate(AppRoute.projects),
                  ),
                  _NavItem(
                    label: 'Agents',
                    icon: Icons.smart_toy_rounded,
                    selected: currentRoute == AppRoute.agents,
                    onTap: () => onNavigate(AppRoute.agents),
                    accentColor: PaperclipTheme.accentPurple,
                  ),
                  _NavItem(
                    label: 'Org Chart',
                    icon: Icons.account_tree_rounded,
                    selected: currentRoute == AppRoute.org,
                    onTap: () => onNavigate(AppRoute.org),
                  ),
                  _NavItem(
                    label: 'Routines',
                    icon: Icons.repeat_rounded,
                    selected: currentRoute == AppRoute.routines,
                    onTap: () => onNavigate(AppRoute.routines),
                  ),
                ]),

                const SizedBox(height: 4),
                const _SectionDivider(label: 'INFRASTRUCTURE'),

                _NavGroup(children: [
                  _NavItem(
                    label: 'Models Library',
                    icon: Icons.storage_rounded,
                    selected: currentRoute == AppRoute.modelsLibrary,
                    onTap: () => onNavigate(AppRoute.modelsLibrary),
                  ),
                  _NavItem(
                    label: 'Device Manager',
                    icon: Icons.devices_rounded,
                    selected: currentRoute == AppRoute.deviceManager,
                    onTap: () => onNavigate(AppRoute.deviceManager),
                  ),
                  _NavItem(
                    label: 'LM Studio',
                    icon: Icons.computer_rounded,
                    selected: currentRoute == AppRoute.lmStudio,
                    onTap: () => onNavigate(AppRoute.lmStudio),
                    badge: state.lmStudioConnected ? 0 : null,
                  ),
                  _NavItem(
                    label: 'Settings',
                    icon: Icons.tune_rounded,
                    selected: currentRoute == AppRoute.settings,
                    onTap: () => onNavigate(AppRoute.settings),
                  ),
                ]),
              ],
            ),
          ),

          // ── Bottom: connection status ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
            ),
            child: Row(children: [
              PcConnectionBadge(
                connected: state.connected,
                label: state.connected ? 'Connected' : 'Offline',
              ),
              const Spacer(),
              if (state.lmStudioConfig.enabled)
                PcConnectionBadge(
                  connected: state.lmStudioConnected,
                  label: 'LM',
                ),
            ]),
          ),
        ],
      ),
    );
  }

  void _showNewIssueDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _NewIssueDialog());
  }
}

// ── Nav Section Divider ──────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav Group (no background, just spacing) ─────────────────────────────────
class _NavGroup extends StatelessWidget {
  final List<Widget> children;
  const _NavGroup({required this.children});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
}

// ── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  final Color? accentColor;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.accentColor,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? PaperclipTheme.accentGreen;

    Color bgColor;
    Color iconColor;
    Color textColor;

    if (widget.selected) {
      bgColor = accent.withValues(alpha: isDark ? 0.12 : 0.08);
      iconColor = accent;
      textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    } else if (_hovered) {
      bgColor = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.05);
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);
    } else {
      bgColor = Colors.transparent;
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
            border: widget.selected
                ? Border.all(color: accent.withValues(alpha: 0.25), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Selected indicator line
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2.5,
                height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(widget.icon, size: 15, color: iconColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.badge != null && widget.badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${widget.badge}',
                      style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sidebar Icon Button ───────────────────────────────────────────────────────
class _SidebarIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _SidebarIconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_SidebarIconBtn> createState() => _SidebarIconBtnState();
}

class _SidebarIconBtnState extends State<_SidebarIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered ? theme.colorScheme.onSurface.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(PaperclipTheme.radiusSm),
            ),
            child: Icon(widget.icon,
                size: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: _hovered ? 0.8 : 0.4)),
          ),
        ),
      ),
    );
  }
}

// ── Company Menu ──────────────────────────────────────────────────────────────
class _CompanyMenu extends StatelessWidget {
  final AppState state;
  const _CompanyMenu({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.companies.length <= 1) {
      return Text(
        state.selectedCompany?.name ?? 'Cyborg AGI',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      color: PaperclipTheme.surfaceElevatedDark,
      elevation: 8,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(PaperclipTheme.radius),
      ),
      itemBuilder: (_) => state.companies
          .map((c) => PopupMenuItem(
                value: c.id,
                child: Text(c.name, style: theme.textTheme.bodyMedium),
              ))
          .toList(),
      onSelected: (id) {
        final company = state.companies.firstWhere((c) => c.id == id);
        state.selectCompany(company);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              state.selectedCompany?.name ?? 'Select Company',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.unfold_more_rounded,
              size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }
}

// ── New Issue Dialog ───────────────────────────────────────────────────────────
class _NewIssueDialog extends StatefulWidget {
  const _NewIssueDialog();

  @override
  State<_NewIssueDialog> createState() => _NewIssueDialogState();
}

class _NewIssueDialogState extends State<_NewIssueDialog> {
  final _titleCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PaperclipTheme.radius)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: PaperclipTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.circle_outlined, size: 16, color: PaperclipTheme.accentGreen),
              ),
              const SizedBox(width: 12),
              Text('New Issue', style: theme.textTheme.titleLarge),
              const Spacer(),
              _SidebarIconBtn(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onTap: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Issue title...'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Issue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final state = context.read<AppState>();
    final company = state.selectedCompany;
    if (company == null) return;

    setState(() => _loading = true);
    try {
      await state.api.createIssue(company.id, {'title': _titleCtrl.text.trim()});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Re-export legacy PcNavItem alias for backward compat ───────────────────
typedef PcNavItem = _NavItem;
