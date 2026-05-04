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
      backgroundColor: AppColors.backgroundMain,
      body: Row(
        children: [
          // 🔹 SIDEBAR - LM Studio Style
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: AppColors.backgroundSidebar,
              border: Border(
                right: BorderSide(color: AppColors.borderDefault, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "CYBORG",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Navigation
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _sideButton("Neural Interface", Icons.psychology),
                      _sideButton("Devices", Icons.devices),
                      _sideButton("GPU", Icons.memory),
                      _sideButton("Vector DB", Icons.storage),
                      _sideButton("Logs", Icons.list),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // System Status Card
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDefault, width: 1),
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
                            "Online",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "RTX 5060 • 12GB",
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 🔹 MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                // 🔹 TOP BAR
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMain,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderDefault, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getIconForTab(selectedTab),
                            color: AppColors.accentBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            selectedTab,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDefault, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_done,
                              color: AppColors.success,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "All Systems Operational",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMain,
                    border: Border(
                      top: BorderSide(color: AppColors.borderDefault, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDefault, width: 1),
                          ),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter command...",
                              hintStyle: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.terminal,
                                color: AppColors.textTertiary,
                                size: 18,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => sendCommand(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: sendCommand,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text("SEND"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
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
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: AppColors.borderDefault,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 PANEL - LM Studio Style
  Widget _panel(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForTab(title),
                color: AppColors.accentBlue,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.borderDefault, height: 1),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }

  // 🔹 SIDEBAR BUTTON - LM Studio Style
  Widget _sideButton(String text, IconData icon) {
    final isSelected = selectedTab == text;
    return GestureDetector(
      onTap: () => switchTab(text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.backgroundSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.borderDefault, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accentBlue : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
