import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class HomeMobile extends StatefulWidget {
  const HomeMobile({super.key});
  @override
  State<HomeMobile> createState() => _HomeMobileState();
}

class _HomeMobileState extends State<HomeMobile> {
  int _selectedIndex = 0;

  static const _tabs = [
    _MobileTab(icon: Icons.chat_bubble_outline, label: 'Chat', path: '/chat'),
    _MobileTab(icon: Icons.memory_outlined, label: 'Models', path: '/models'),
    _MobileTab(icon: Icons.hub_outlined, label: 'Graph', path: '/graph'),
    _MobileTab(icon: Icons.task_alt_outlined, label: 'Tasks', path: '/gsd'),
    _MobileTab(icon: Icons.settings_outlined, label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: _buildAppBar(),
      body: _buildBody(context),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundSidebar,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.android, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 9),
          const Text(
            'CYBORG',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.accentGreen.withOpacity(0.3), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.accentGreen,
                  boxShadow: [BoxShadow(color: AppColors.accentGreen.withOpacity(0.6), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 5),
              const Text('Online', style: TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_selectedIndex) {
      0 => _QuickChatBody(onOpenChat: () => context.go('/chat')),
      1 => _QuickModelsBody(onOpenModels: () => context.go('/models')),
      _ => _PlaceholderBody(tab: _tabs[_selectedIndex]),
    };
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundSidebar,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final active = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon, size: 20,
                          color: active ? AppColors.accent : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: active ? AppColors.accent : AppColors.textTertiary,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Chat Body ──────────────────────────────────────────────────────────

class _QuickChatBody extends StatelessWidget {
  final VoidCallback onOpenChat;
  const _QuickChatBody({required this.onOpenChat});

  static const _features = [
    _FeatureCard(icon: Icons.code, label: 'Code', color: AppColors.accentGreen, path: '/chat'),
    _FeatureCard(icon: Icons.local_hospital_outlined, label: 'Health', color: AppColors.accentRed, path: '/health'),
    _FeatureCard(icon: Icons.school_outlined, label: 'Edu', color: AppColors.accentYellow, path: '/education'),
    _FeatureCard(icon: Icons.hub_outlined, label: 'Graph', color: AppColors.accentPurple, path: '/graph'),
    _FeatureCard(icon: Icons.search, label: 'Search', color: AppColors.accentBlue, path: '/chat'),
    _FeatureCard(icon: Icons.task_alt_outlined, label: 'Tasks', color: AppColors.accentOrange, path: '/gsd'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.android, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cyborg AI', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Local-first AI assistant', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Start Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('QUICK ACCESS',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: _features.map((f) => _MobileFeatureTile(feature: f)).toList(),
          ),
          const SizedBox(height: 20),
          const Text('RECENT CONVERSATIONS',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          ...List.generate(3, (i) => _RecentConvoTile(index: i, onTap: onOpenChat)),
        ],
      ),
    );
  }
}

class _MobileFeatureTile extends StatelessWidget {
  final _FeatureCard feature;
  const _MobileFeatureTile({required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(feature.path),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: feature.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(feature.icon, color: feature.color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(feature.label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _RecentConvoTile extends StatelessWidget {
  final int index;
  final VoidCallback onTap;
  const _RecentConvoTile({required this.index, required this.onTap});

  static const _titles = ['Analyze my Python project', 'Explain neural networks', 'Draft project proposal'];
  static const _times = ['2h ago', 'Yesterday', '3 days ago'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_titles[index],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(_times[index], style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Models Body ────────────────────────────────────────────────────────

class _QuickModelsBody extends StatelessWidget {
  final VoidCallback onOpenModels;
  const _QuickModelsBody({required this.onOpenModels});

  static const _sampleModels = [
    _ModelSample(name: 'Gemma 4 E2B', size: '5.95 GB', quant: 'Q8_0', tags: ['Vision', 'Tool Use']),
    _ModelSample(name: 'Qwen3 8B Claude', size: '4.68 GB', quant: 'Q4_K_M', tags: ['Reasoning']),
    _ModelSample(name: 'Qwen3.5 9B', size: '6.10 GB', quant: 'Q4_K_M', tags: ['Vision', 'Tool Use']),
    _ModelSample(name: 'GLM 4.6v Flash', size: '7.41 GB', quant: 'Q4_K_M', tags: ['Vision']),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MY MODELS',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  TextButton(
                    onPressed: onOpenModels,
                    child: const Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sampleModels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _MobileModelTile(model: _sampleModels[i], onTap: onOpenModels),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenModels,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Browse HuggingFace', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileModelTile extends StatelessWidget {
  final _ModelSample model;
  final VoidCallback onTap;
  const _MobileModelTile({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniTag(model.quant, color: AppColors.accentBlue),
                      const SizedBox(width: 6),
                      _MiniTag(model.size),
                      const SizedBox(width: 6),
                      ...model.tags.take(1).map((t) => _MiniTag(t)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label; final Color? color;
  const _MiniTag(this.label, {this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: (color ?? AppColors.textTertiary).withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color ?? AppColors.textTertiary)),
  );
}

// ─── Placeholder ──────────────────────────────────────────────────────────────

class _PlaceholderBody extends StatelessWidget {
  final _MobileTab tab;
  const _PlaceholderBody({required this.tab});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(tab.icon, size: 30, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 16),
        Text(tab.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Coming soon', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => context.go(tab.path),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Open ${tab.label}'),
        ),
      ],
    ),
  );
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _MobileTab {
  final IconData icon; final String label; final String path;
  const _MobileTab({required this.icon, required this.label, required this.path});
}

class _FeatureCard {
  final IconData icon; final String label; final Color color; final String path;
  const _FeatureCard({required this.icon, required this.label, required this.color, required this.path});
}

class _ModelSample {
  final String name; final String size; final String quant; final List<String> tags;
  const _ModelSample({required this.name, required this.size, required this.quant, required this.tags});
}
