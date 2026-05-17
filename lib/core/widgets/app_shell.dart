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
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Scaffold(
        key: GlobalKey<ScaffoldState>(),
        backgroundColor: AppColors.backgroundMain,
        appBar: AppBar(
          toolbarHeight: 52,
          backgroundColor: AppColors.backgroundSidebar,
          title: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.android, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              const Text(
                'CYBORG',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, size: 20),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.border),
          ),
        ),
        drawer: Drawer(
          width: 260,
          backgroundColor: AppColors.backgroundSidebar,
          child: _CyborgSidebar(currentLocation: location, isDrawer: true),
        ),
        body: child,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
  final bool isDrawer;
  const _CyborgSidebar({required this.currentLocation, this.isDrawer = false});

  @override
  ConsumerState<_CyborgSidebar> createState() => _CyborgSidebarState();
}

class _CyborgSidebarState extends ConsumerState<_CyborgSidebar> {
  bool _expanded = true;

  static const _navGroups = [
    _NavGroup(label: null, items: [
      _NavItem(icon: Icons.chat_bubble_outline, label: 'Chat', path: '/chat'),
    ]),
    _NavGroup(label: 'KNOWLEDGE', items: [
      _NavItem(icon: Icons.hub_outlined, label: 'Knowledge Graph', path: '/graph'),
      _NavItem(icon: Icons.upload_file_outlined, label: 'Ingest', path: '/ingest'),
      _NavItem(icon: Icons.lock_outline, label: 'Vault', path: '/vault'),
    ]),
    _NavGroup(label: 'AI', items: [
      _NavItem(icon: Icons.memory_outlined, label: 'Models', path: '/models'),
    ]),
    _NavGroup(label: 'WORKSPACE', items: [
      _NavItem(icon: Icons.task_alt_outlined, label: 'GSD Projects', path: '/gsd'),
      _NavItem(icon: Icons.code_outlined, label: 'CodeFlow', path: '/codeflow'),
      _NavItem(icon: Icons.waves_outlined, label: 'MiroFish', path: '/mirofish'),
      _NavItem(icon: Icons.psychology_outlined, label: 'Skills', path: '/skills'),
    ]),
    _NavGroup(label: 'EXTENSIONS', items: [
      _NavItem(icon: Icons.local_hospital_outlined, label: 'Health Track', path: '/health'),
      _NavItem(icon: Icons.school_outlined, label: 'Education', path: '/education'),
    ]),
    _NavGroup(label: 'MONITOR', items: [
      _NavItem(icon: Icons.public_outlined, label: 'World Monitor', path: '/monitor'),
      _NavItem(icon: Icons.devices_outlined, label: 'Devices', path: '/devices'),
    ]),
    _NavGroup(label: 'TOOLS', items: [
      _NavItem(icon: Icons.cloud_sync_outlined, label: 'GitHub', path: '/github'),
      _NavItem(icon: Icons.settings_outlined, label: 'Settings', path: '/settings'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final backendStatus = ref.watch(backendStatusProvider);
    final isExpanded = widget.isDrawer || _expanded;
    final w = isExpanded ? (widget.isDrawer ? double.infinity : 220.0) : 56.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: w,
      height: double.infinity,
      color: AppColors.backgroundSidebar,
      child: Column(
        children: [
          _buildHeader(isExpanded),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _buildNavItems(isExpanded),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildFooter(backendStatus, isExpanded),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(bool expanded) {
    final items = <Widget>[];
    for (final group in _navGroups) {
      if (expanded && group.label != null) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Text(
            group.label!,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ));
      } else if (!expanded && group.label != null) {
        items.add(const SizedBox(height: 3));
        items.add(Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 1,
          color: AppColors.border,
        ));
        items.add(const SizedBox(height: 3));
      }
      for (final item in group.items) {
        final isActive = widget.currentLocation.startsWith(item.path);
        items.add(_NavTile(
          item: item,
          isActive: isActive,
          isExpanded: expanded,
          onTap: () {
            context.go(item.path);
            if (widget.isDrawer) Navigator.of(context).pop();
          },
        ));
      }
    }
    return items;
  }

  Widget _buildHeader(bool expanded) {
    return GestureDetector(
      onTap: () {
        if (!expanded && !widget.isDrawer) setState(() => _expanded = true);
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.android, color: Colors.white, size: 17),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'CYBORG',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!widget.isDrawer)
                GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: const Icon(Icons.chevron_left,
                      color: AppColors.textTertiary, size: 18),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AsyncValue<BackendProgress> status, bool expanded) {
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
        : starting ? AppColors.accentYellow : AppColors.accentRed;

    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 8),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              _StatusDot(color: dotColor, pulse: running),
              if (expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    running
                        ? 'Online'
                        : starting ? 'Starting…' : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        color: dotColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (running)
                  _MiniChip(
                      label: cudaActive ? 'GPU' : 'CPU',
                      color: cudaActive ? AppColors.accent : AppColors.textMuted),
              ],
            ],
          ),
        ),
        _UserTile(user: user, expanded: expanded),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ─── Nav Tile ─────────────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.isActive, required this.isExpanded, required this.onTap});
  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? AppColors.accent.withOpacity(0.12)
        : _hovered ? AppColors.backgroundSurface : Colors.transparent;
    final fg = widget.isActive ? AppColors.accent : AppColors.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 6 : 4, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 10 : 0, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: widget.isActive ? Border.all(color: AppColors.accent.withOpacity(0.25), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(widget.item.icon, size: 16, color: fg),
              if (widget.isExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.item.label,
                      style: TextStyle(fontSize: 13, color: fg, fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final Color color; final bool pulse;
  const _StatusDot({required this.color, required this.pulse});
  @override
  Widget build(BuildContext context) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: color,
      boxShadow: pulse ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)] : null,
    ),
  );
}

class _MiniChip extends StatelessWidget {
  final String label; final Color color;
  const _MiniChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.25), width: 0.5),
    ),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
  );
}

class _UserTile extends StatelessWidget {
  final dynamic user; final bool expanded;
  const _UserTile({required this.user, required this.expanded});
  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName ?? user?.email?.split('@').first ?? '').trim();
    final displayName = name.isNotEmpty ? name : 'User';
    final initial = displayName[0].toUpperCase();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 4, vertical: 2),
      child: Row(
        mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundImage: (user?.photoURL?.isNotEmpty == true) ? NetworkImage(user!.photoURL!) : null,
            backgroundColor: AppColors.accent.withOpacity(0.18),
            child: (user?.photoURL?.isNotEmpty != true)
                ? Text(initial, style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700))
                : null,
          ),
          if (expanded) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(displayName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: const Icon(Icons.logout_outlined, size: 15, color: AppColors.textTertiary),
              onPressed: () => FirebaseAuth.instance.signOut(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Sign out',
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon; final String label; final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}

class _NavGroup {
  final String? label; final List<_NavItem> items;
  const _NavGroup({required this.label, required this.items});
}