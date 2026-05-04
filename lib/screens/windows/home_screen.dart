import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HomeDesktop extends StatefulWidget {
  const HomeDesktop({super.key});

  @override
  State<HomeDesktop> createState() => _HomeDesktopState();
}

class _HomeDesktopState extends State<HomeDesktop> {
  final TextEditingController _controller = TextEditingController();

  String selectedTab = "Neural Interface";
  String output = "System Ready...";
  List<String> logs = [];

  void sendCommand() {
    if (_controller.text.isEmpty) return;

    setState(() {
      logs.add("> ${_controller.text}");
      output = "Executed: ${_controller.text}";
      _controller.clear();
    });
  }

  void switchTab(String tab) {
    setState(() {
      selectedTab = tab;
      output = "$tab opened";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 🔹 SIDEBAR
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "CYBORG",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sideButton("Neural Interface", Icons.psychology),
                _sideButton("Devices", Icons.devices),
                _sideButton("GPU", Icons.memory),
                _sideButton("Vector DB", Icons.storage),
                _sideButton("Logs", Icons.list),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "System Online",
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "RTX 5060 • 12GB",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // 🔹 MAIN
          Expanded(
            child: Column(
              children: [
                // 🔹 TOP BAR
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getIconForTab(selectedTab),
                            color: AppColors.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            selectedTab,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_done,
                              color: AppColors.success,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "All Systems Operational",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔹 BODY
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(),
                  ),
                ),

                // 🔹 INPUT BAR
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter command...",
                              hintStyle: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.terminal,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => sendCommand(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: sendCommand,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text("SEND"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  IconData _getIconForTab(String tab) {
    switch (tab) {
      case "Neural Interface":
        return Icons.psychology;
      case "Devices":
        return Icons.devices;
      case "GPU":
        return Icons.memory;
      case "Vector DB":
        return Icons.storage;
      case "Logs":
        return Icons.list;
      default:
        return Icons.dashboard;
    }
  }

  // 🔹 DYNAMIC CONTENT
  Widget _buildContent() {
    switch (selectedTab) {
      case "Neural Interface":
        return _panel(
          "Neural Interface",
          Center(
            child: Text(
              output,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        );

      case "Devices":
        return _panel(
          "Devices",
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    output = "Scanning devices...";
                  });
                },
                icon: const Icon(Icons.scan, size: 18),
                label: const Text("SCAN DEVICES"),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  output,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );

      case "GPU":
        return _panel(
          "GPU Telemetry",
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _telemetryCard("VRAM Usage", "2.2 GB", "12 GB Total", 18),
              const SizedBox(height: 12),
              _telemetryCard("GPU Load", "30%", "RTX 5060", 30),
            ],
          ),
        );

      case "Vector DB":
        return _panel(
          "Vector Database",
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    output = "Vector DB refreshed";
                  });
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("REFRESH"),
              ),
              const SizedBox(height: 16),
              Text(
                output,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );

      case "Logs":
        return _panel(
          "System Logs",
          logs.isEmpty
              ? Center(
                  child: Text(
                    "No logs yet",
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) => Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.terminal,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            logs[i],
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _telemetryCard(String label, String value, String subtitle, int percentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 PANEL
  Widget _panel(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForTab(title),
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  // 🔹 SIDEBAR BUTTON
  Widget _sideButton(String text, IconData icon) {
    final isSelected = selectedTab == text;
    return GestureDetector(
      onTap: () => switchTab(text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceVariant : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.accent.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
