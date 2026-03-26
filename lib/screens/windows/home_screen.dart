import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFF050B14),
      body: Row(
        children: [
          // 🔹 SIDEBAR
          Container(
            width: 220,
            color: const Color(0xFF081421),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  "CYBORG",
                  style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 22,
                      letterSpacing: 4),
                ),
                const SizedBox(height: 20),
                _sideButton("Neural Interface"),
                _sideButton("Devices"),
                _sideButton("GPU"),
                _sideButton("Vector DB"),
                _sideButton("Logs"),
              ],
            ),
          ),

          // 🔹 MAIN
          Expanded(
            child: Column(
              children: [
                // 🔹 TOP BAR
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFF081421),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("CYBORG • $selectedTab",
                          style: const TextStyle(
                              color: Colors.cyanAccent, fontSize: 16)),
                      const Text("RTX 5060 • Ready",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                // 🔹 BODY
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildContent(),
                  ),
                ),

                // 🔹 INPUT BAR
                Container(
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF081421),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Enter command...",
                            hintStyle:
                                const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF050B14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) => sendCommand(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: sendCommand,
                        child: const Text("SEND"),
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

  // 🔹 DYNAMIC CONTENT
  Widget _buildContent() {
    switch (selectedTab) {
      case "Neural Interface":
        return _panel(
          "Neural Interface",
          Center(
            child: Text(output,
                style: const TextStyle(color: Colors.white)),
          ),
        );

      case "Devices":
        return _panel(
          "Devices",
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    output = "Scanning devices...";
                  });
                },
                child: const Text("SCAN DEVICES"),
              ),
              const SizedBox(height: 10),
              Text(output, style: const TextStyle(color: Colors.white)),
            ],
          ),
        );

      case "GPU":
        return _panel(
          "GPU Telemetry",
          Column(
            children: const [
              Text("VRAM: 2.2 GB",
                  style: TextStyle(color: Colors.white)),
              Text("Usage: 30%",
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        );

      case "Vector DB":
        return _panel(
          "Vector Database",
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    output = "Vector DB refreshed";
                  });
                },
                child: const Text("REFRESH"),
              ),
              const SizedBox(height: 10),
              Text(output, style: const TextStyle(color: Colors.white)),
            ],
          ),
        );

      case "Logs":
        return _panel(
          "Logs",
          ListView(
            children: logs
                .map((e) => Text(e,
                    style: const TextStyle(color: Colors.greenAccent)))
                .toList(),
          ),
        );

      default:
        return const SizedBox();
    }
  }

  // 🔹 PANEL
  Widget _panel(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A2B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.cyanAccent, fontSize: 16)),
          const Divider(color: Colors.white24),
          Expanded(child: child),
        ],
      ),
    );
  }

  // 🔹 SIDEBAR BUTTON
  Widget _sideButton(String text) {
    return GestureDetector(
      onTap: () => switchTab(text),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(text,
              style: const TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}