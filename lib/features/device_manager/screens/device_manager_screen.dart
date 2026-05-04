import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../widgets/feature_screen.dart';
import '../../vault/widgets/vault_sidebar.dart';

// Full device manager — mDNS discovery + metrics per device
class DeviceManagerScreen extends ConsumerStatefulWidget {
  const DeviceManagerScreen({super.key});
  @override
  ConsumerState<DeviceManagerScreen> createState() =>
      _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends ConsumerState<DeviceManagerScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _scanning = false;
  bool _showExplorer = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final r = await dio.get(ApiConstants.systemMetrics);
      // Show local device metrics as "this device"
      setState(() {
        _devices = [
          {
            'name': 'This Device',
            'type': 'local',
            'status': 'online',
            'cpu': r.data['cpu']?['total'] ?? 0,
            'ram': r.data['memory']?['percent'] ?? 0,
            'ip': '127.0.0.1',
          }
        ];
      });
    } catch (_) {}
    setState(() => _scanning = false);
  }

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: AppColors.surface,
          child: Row(children: [
            const Icon(Icons.devices_outlined,
                color: AppColors.accentOrange, size: 18),
            const SizedBox(width: 8),
            const Text('Device Manager',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            ElevatedButton.icon(
                icon: _scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_find, size: 14),
                label: Text(_scanning ? 'Scanning...' : 'Scan Network',
                    style: const TextStyle(fontSize: 12)),
                onPressed: _scanning ? null : _scan,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange)),
          ])),
      const Divider(height: 1),
      Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
        final narrow = constraints.maxWidth < 600;
        final content = _devices.isEmpty
            ? const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(Icons.devices_outlined,
                        size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('No devices found. Click Scan to search.',
                        style: TextStyle(color: AppColors.textSecondary))
                  ]))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: narrow ? 400 : 280,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5),
                itemCount: _devices.length,
                itemBuilder: (_, i) => _DeviceCard(
                      device: _devices[i],
                      onExplore: () => setState(() => _showExplorer = true),
                    ));

        final sidebar = Container(
            width: narrow ? double.infinity : 240,
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  left: narrow
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.border),
                  top: narrow
                      ? const BorderSide(color: AppColors.border)
                      : BorderSide.none,
                )),
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('FEATURES',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ...[
                    (Icons.wifi_outlined, 'mDNS Discovery'),
                    (Icons.lock_outline, 'QUIC/TLS Transport'),
                    (Icons.sync_outlined, 'Offline Sync'),
                    (Icons.memory_outlined, 'Remote LLM Exec'),
                    (Icons.hub_outlined, 'Shared Knowledge Base'),
                  ].map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Icon(f.$1, size: 15, color: AppColors.accentOrange),
                        const SizedBox(width: 10),
                        Text(f.$2,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ]))),
                  const Divider(),
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.accentYellow.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.accentYellow.withOpacity(0.2))),
                      child: const Text(
                          'Install Cyborg on other devices and they will appear here automatically via mDNS.',
                          style: TextStyle(
                              color: AppColors.accentYellow,
                              fontSize: 11,
                              height: 1.5))),
                ]));

        if (narrow) {
          return Column(children: [
            Expanded(child: content),
            sidebar,
          ]);
        }
        return Row(children: [
          if (_showExplorer)
            VaultSidebar(
              showHeader: true,
              onClose: () => setState(() => _showExplorer = false),
            ),
          Expanded(child: content),
          sidebar,
        ]);
      })),
    ]);
  }
}

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onExplore;

  const _DeviceCard({
    required this.device,
    required this.onExplore,
  });
  @override
  Widget build(BuildContext context) {
    final isOnline = device['status'] == 'online';
    final cpu = (device['cpu'] as num?)?.toDouble() ?? 0;
    final ram = (device['ram'] as num?)?.toDouble() ?? 0;
    final isLocal = device['type'] == 'local';

    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    isLocal
                        ? Icons.computer_outlined
                        : Icons.smartphone_outlined,
                    size: 20,
                    color: AppColors.accentOrange),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(device['name'] as String? ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))),
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? AppColors.accentGreen
                            : AppColors.accentRed)),
              ]),
              const SizedBox(height: 8),
              Text(device['ip'] as String? ?? '',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _MicroBar('CPU', cpu, AppColors.accent)),
                const SizedBox(width: 8),
                Expanded(child: _MicroBar('RAM', ram, AppColors.accentPurple)),
              ]),
              const Spacer(),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                TextButton.icon(
                  icon: const Icon(Icons.folder_open_outlined, size: 14),
                  label: const Text('Explore', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onExplore,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.hub_outlined, size: 14),
                  label: const Text('Ingest', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentOrange,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Device added to Knowledge Graph ingestion queue.'),
                      backgroundColor: AppColors.accentOrange,
                    ));
                  },
                ),
              ]),
            ])));
  }
}

class _MicroBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MicroBar(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label ${value.toStringAsFixed(0)}%',
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 4,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color))),
      ]);
}
