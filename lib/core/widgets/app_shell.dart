import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../services/backend_service.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: Row(
        children: [
          _CyborgSidebar(currentLocation: location),
          Container(width: 1, color: AppColors.border),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CyborgSidebar extends ConsumerStatefulWidget {
  final String currentLocation;
  const _CyborgSidebar({required this.currentLocation});

  @override
  ConsumerState<_CyborgSidebar> createState() => _CyborgSidebarState();
}

class _CyborgSidebarState extends ConsumerState<_CyborgSidebar> {
  bool _expanded = true;

  static const _navItems = [
    _NavItem(
        icon: Icons.chat_bubble_outline,
        label: 'Chat',
        path: '/chat',
        group: 'main'),
    _NavItem(
        icon: Icons.hub_outlined,
        label: 'Knowledge Graph',
        path: '/graph',
        group: 'knowledge'),
    _NavItem(
        icon: Icons.upload_file_outlined,
        label: 'Ingest',
        path: '/ingest',
        group: 'knowledge'),
    _NavItem(
        icon: Icons.edit_note_outlined,
        label: 'Vault',
        path: '/vault',
        group: 'knowledge'),
    _NavItem(
        icon: Icons.memory_outlined,
        label: 'Models',
        path: '/models',
        group: 'ai'),
    _NavItem(
        icon: Icons.task_alt_outlined,
        label: 'GSD Projects',
        path: '/gsd',
        group: 'work'),
    _NavItem(
        icon: Icons.code_outlined,
        label: 'CodeFlow',
        path: '/codeflow',
        group: 'work'),
    _NavItem(
        icon: Icons.waves_outlined,
        label: 'MiroFish',
        path: '/mirofish',
        group: 'work'),
    // ── Gemma 4 Extension ────────────────────────────────────────────────
    _NavItem(
        icon: Icons.local_hospital_outlined,
        label: 'Health Track',
        path: '/health',
        group: 'gemma4'),
    _NavItem(
        icon: Icons.school_outlined,
        label: 'Education',
        path: '/education',
        group: 'gemma4'),
    // ─────────────────────────────────────────────────────────────────────
    _NavItem(
        icon: Icons.public_outlined,
        label: 'World Monitor',
        path: '/monitor',
        group: 'monitor'),
    _NavItem(
        icon: Icons.devices_outlined,
        label: 'Devices',
        path: '/devices',
        group: 'monitor'),
    _NavItem(
        icon: Icons.cloud_sync_outlined,
        label: 'GitHub',
        path: '/github',
        group: 'tools'),
    _NavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        path: '/settings',
        group: 'tools'),
  ];

  static const _groupLabels = {
    'main': null,
    'knowledge': 'KNOWLEDGE',
    'ai': 'AI',
    'work': 'WORKSPACE',
    'gemma4': 'GEMMA 4',
    'monitor': 'MONITOR',
    'tools': 'TOOLS',
  };

  @override
  Widget build(BuildContext context) {
    final backendStatus = ref.watch(backendStatusProvider);
    final w = _expanded ? 220.0 : 60.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w,
      color: AppColors.surface,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: _buildNavItems(),
            ),
          ),
          const Divider(height: 1),
          _buildFooter(backendStatus),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems() {
    final items = <Widget>[];
    String? lastGroup;

    for (final item in _navItems) {
      if (item.group != lastGroup && _expanded) {
        final label = _groupLabels[item.group];
        if (label != null) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
          ));
        }
        lastGroup = item.group;
      }
      final isActive = widget.currentLocation.startsWith(item.path);
      items.add(_NavTile(
        item: item,
        isActive: isActive,
        isExpanded: _expanded,
        onTap: () => context.go(item.path),
      ));
    }
    return items;
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        if (!_expanded) setState(() => _expanded = true);
      },
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.android, color: Colors.white, size: 18),
            ),
            if (_expanded) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text('CYBORG',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textSecondary, size: 18),
                onPressed: () => setState(() => _expanded = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AsyncValue<BackendProgress> status) {
    final user = FirebaseAuth.instance.currentUser;
    final s = status.value?.status;
    final running = s == BackendStatus.running;
    final starting = s == BackendStatus.starting ||
        s == BackendStatus.checkingEnv ||
        s == BackendStatus.detectingCuda ||
        s == BackendStatus.creatingVenv ||
        s == BackendStatus.installingTorch ||
        s == BackendStatus.installingDeps;
    final cudaActive = status.value?.cudaActive ?? false;
    final dotColor = running
        ? AppColors.accentGreen
        : starting
            ? AppColors.accentYellow
            : AppColors.accentRed;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: running
                      ? [
                          BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.6),
                              blurRadius: 6)
                        ]
                      : null,
                ),
              ),
              if (_expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    running
                        ? 'Online'
                        : starting
                            ? 'Starting...'
                            : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        color: dotColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (running)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cudaActive
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.textMuted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: cudaActive
                              ? AppColors.accent.withOpacity(0.3)
                              : AppColors.border,
                          width: 0.5),
                    ),
                    child: Text(
                      cudaActive ? 'GPU' : 'CPU',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color:
                            cudaActive ? AppColors.accent : AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: _expanded ? 12 : 8),
          leading: CircleAvatar(
            radius: 14,
            backgroundImage: (user?.photoURL?.isNotEmpty == true)
                ? NetworkImage(user!.photoURL!)
                : null,
            backgroundColor: AppColors.accent.withOpacity(0.2),
            child: (user?.photoURL?.isNotEmpty != true)
                ? Text((user?.email ?? 'C')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          title: _expanded
              ? Text(
                  user?.displayName ?? user?.email?.split('@').first ?? 'User',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: _expanded
              ? IconButton(
                  icon: const Icon(Icons.logout_outlined,
                      size: 16, color: AppColors.textSecondary),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints())
              : null,
          dense: true,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  final String group;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.path,
      required this.group});
}

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;
  const _NavTile(
      {required this.item,
      required this.isActive,
      required this.isExpanded,
      required this.onTap});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? AppColors.accent.withOpacity(0.15)
        : _hovered
            ? AppColors.surfaceVariant
            : Colors.transparent;
    final iconColor =
        widget.isActive ? AppColors.accent : AppColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: widget.isActive
                ? Border.all(color: AppColors.accent.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 17, color: iconColor),
              if (widget.isExpanded) ...[
                const SizedBox(width: 10),
                Text(widget.item.label,
                    style: TextStyle(
                        fontSize: 13,
                        color: iconColor,
                        fontWeight: widget.isActive
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
