import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/paperclip_theme.dart';
import '../../../core/services/health_edu_service.dart';
import 'health_screen.dart';
import 'education_screen.dart';

// Local shim so existing AppColors references resolve without rewriting every line
class AppColors {
  static const Color backgroundMain    = PaperclipTheme.backgroundDark;
  static const Color backgroundSidebar = PaperclipTheme.sidebarDark;
  static const Color backgroundSurface = PaperclipTheme.surfaceDark;
  static const Color backgroundInput   = PaperclipTheme.surfaceElevatedDark;
  static const Color borderDefault     = PaperclipTheme.borderDark;
  static const Color borderHover       = PaperclipTheme.borderBrightDark;
  static const Color textPrimary       = PaperclipTheme.foregroundDark;
  static const Color textSecondary     = PaperclipTheme.mutedDark;
  static const Color textTertiary      = PaperclipTheme.mutedFgDark;
  static const Color textMuted         = PaperclipTheme.mutedFgDark;
  static const Color accentBlue        = PaperclipTheme.accentCyan;
  static const Color accentBlueHover   = Color(0xFF00A0D6);
  static const Color accent            = PaperclipTheme.accentCyan;
  static const Color accentPurple      = PaperclipTheme.accentPurple;
  static const Color accentGreen       = PaperclipTheme.accentGreen;
  static const Color accentRed         = PaperclipTheme.accentRed;
  static const Color accentOrange      = PaperclipTheme.accentAmber;
  static const Color accentYellow      = PaperclipTheme.accentAmber;
  static const Color success           = PaperclipTheme.accentGreen;
  static const Color warning           = PaperclipTheme.accentAmber;
  static const Color error             = PaperclipTheme.accentRed;
  static const Color info              = PaperclipTheme.accentCyan;
  static const Color surface           = PaperclipTheme.surfaceDark;
  static const Color surfaceVariant    = PaperclipTheme.surfaceElevatedDark;
  static const Color background        = PaperclipTheme.backgroundDark;
  static const Color border            = PaperclipTheme.borderDark;
  static const LinearGradient accentGradient = LinearGradient(
    colors: [PaperclipTheme.accentGreen, PaperclipTheme.accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class HomeDesktop extends StatefulWidget {
  const HomeDesktop({super.key});

  @override
  State<HomeDesktop> createState() => _HomeDesktopState();
}

class _HomeDesktopState extends State<HomeDesktop> {
  final TextEditingController _controller = TextEditingController();
  final HealthEduService _healthEduService = HealthEduService();

  String selectedTab = "Neural Interface";
  String output = "System Ready...";
  List<String> logs = [];

  // Health & Education state
  bool _isAnalyzingXRay = false;
  bool _isGradingHomework = false;
  bool _isGeneratingQuiz = false;
  Map<String, dynamic>? _xrayResult;
  Map<String, dynamic>? _homeworkResult;
  Map<String, dynamic>? _quizResult;
  Map<String, dynamic>? _healthConfig;
  Map<String, dynamic>? _educationConfig;

  @override
  void initState() {
    super.initState();
    _loadDemoConfigs();
  }

  Future<void> _loadDemoConfigs() async {
    _healthConfig = await _healthEduService.getHealthDemoConfig();
    _educationConfig = await _healthEduService.getEducationDemoConfig();
    if (mounted) setState(() {});
  }

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
      backgroundColor: PaperclipTheme.backgroundDark,
      body: Row(
        children: [
          // 🔹 SIDEBAR - LM Studio Style
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: PaperclipTheme.sidebarDark,
              border: Border(
                right: BorderSide(color: PaperclipTheme.borderDark, width: 1),
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
                          gradient: PaperclipTheme.accentCyanGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.smart_toy,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "CYBORG",
                        style: TextStyle(
                          color: PaperclipTheme.foregroundDark,
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
                      const SizedBox(height: 12),
                      // Gemma 4 Extensions
                      _sideButton("Health Track", Icons.medical_services,
                          isCategory: true),
                      _sideButton("X-Ray Analysis", Icons.add_chart),
                      _sideButton("EHR Assistant", Icons.folder_shared),
                      const SizedBox(height: 12),
                      _sideButton("Education Track", Icons.school,
                          isCategory: true),
                      _sideButton(
                          "Homework Grader", Icons.assignment_turned_in),
                      _sideButton("Quiz Generator", Icons.quiz),
                      const SizedBox(height: 12),
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
                    color: PaperclipTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: PaperclipTheme.borderDark, width: 1),
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
                              color: PaperclipTheme.accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Online",
                            style: TextStyle(
                              color: PaperclipTheme.foregroundDark,
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
                          color: PaperclipTheme.mutedFgDark,
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
                    color: PaperclipTheme.backgroundDark,
                    border: Border(
                      bottom:
                          BorderSide(color: PaperclipTheme.borderDark, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getIconForTab(selectedTab),
                            color: PaperclipTheme.accentCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            selectedTab,
                            style: const TextStyle(
                              color: PaperclipTheme.foregroundDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: PaperclipTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: PaperclipTheme.borderDark, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_done,
                              color: PaperclipTheme.accentGreen,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "All Systems Operational",
                              style: TextStyle(
                                color: PaperclipTheme.mutedDark,
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
                    color: PaperclipTheme.backgroundDark,
                    border: Border(
                      top: BorderSide(color: PaperclipTheme.borderDark, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: PaperclipTheme.surfaceElevatedDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: PaperclipTheme.borderDark, width: 1),
                          ),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(
                              color: PaperclipTheme.foregroundDark,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter command...",
                              hintStyle: const TextStyle(
                                color: PaperclipTheme.mutedFgDark,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.terminal,
                                color: PaperclipTheme.mutedFgDark,
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
      case "Health Track":
      case "Education Track":
        return Icons.folder_special;
      case "X-Ray Analysis":
        return Icons.add_chart;
      case "EHR Assistant":
        return Icons.folder_shared;
      case "Homework Grader":
        return Icons.assignment_turned_in;
      case "Quiz Generator":
        return Icons.quiz;
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
                color: PaperclipTheme.foregroundDark,
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
                  color: PaperclipTheme.surfaceElevatedDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PaperclipTheme.borderDark),
                ),
                child: Text(
                  output,
                  style: const TextStyle(
                    color: PaperclipTheme.foregroundDark,
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
                  color: PaperclipTheme.foregroundDark,
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
                    style: TextStyle(color: PaperclipTheme.mutedFgDark),
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
                          color: PaperclipTheme.borderDark,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.terminal,
                          color: PaperclipTheme.accentGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            logs[i],
                            style: const TextStyle(
                              color: PaperclipTheme.foregroundDark,
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

      case "Health Track":
        return _panel(
          "Health Track - Gemma 4 MedGemma",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _featureCard(
                "🏥 Medical AI Assistant",
                "Offline-first chest X-ray analysis using MedGemma 4B with vision encoder.",
                Icons.medical_services,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          output =
                              "Launching X-Ray Analysis Demo on port 7860...";
                        });
                      },
                      icon: const Icon(Icons.add_chart, size: 18),
                      label: const Text("X-RAY ANALYSIS"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          output = "Launching EHR Assistant Demo...";
                        });
                      },
                      icon: const Icon(Icons.folder_shared, size: 18),
                      label: const Text("EHR ASSISTANT"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaperclipTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PaperclipTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "⚠️ Medical Disclaimer",
                      style: TextStyle(
                        color: PaperclipTheme.accentAmber,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This AI assistant is for educational and research purposes only. "
                      "It is NOT a substitute for professional medical advice, diagnosis, or treatment. "
                      "Always consult qualified healthcare providers for medical concerns.",
                      style: TextStyle(
                        color: PaperclipTheme.mutedDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case "Education Track":
        return _panel(
          "Education Track - Gemma 4 Adaptive Tutor",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _featureCard(
                "📚 Adaptive Learning System",
                "Multilingual homework grading and quiz generation with cultural relevance (en, es, hi).",
                Icons.school,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          output =
                              "Launching Homework Grader Demo on port 7861...";
                        });
                      },
                      icon: const Icon(Icons.assignment_turned_in, size: 18),
                      label: const Text("HOMEWORK GRADER"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          output = "Launching Quiz Generator Demo...";
                        });
                      },
                      icon: const Icon(Icons.quiz, size: 18),
                      label: const Text("QUIZ GENERATOR"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaperclipTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PaperclipTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "🌍 Supported Languages",
                      style: TextStyle(
                        color: PaperclipTheme.accentCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "English • Español • हिन्दी\n"
                      "Optimized for rural/low-resource deployment on edge devices.",
                      style: TextStyle(
                        color: PaperclipTheme.mutedDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case "X-Ray Analysis":
        return _panel(
          "X-Ray Analysis",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload chest X-ray for MedGemma 4B analysis",
                style: TextStyle(
                  color: PaperclipTheme.foregroundDark,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isAnalyzingXRay ? null : _uploadAndAnalyzeXRay,
                icon: _isAnalyzingXRay
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(_isAnalyzingXRay ? "ANALYZING..." : "UPLOAD X-RAY"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              if (_xrayResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PaperclipTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PaperclipTheme.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.analytics,
                              color: PaperclipTheme.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Analysis Results",
                            style: TextStyle(
                              color: PaperclipTheme.foregroundDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _resultRow("Findings",
                          _xrayResult!['findings']?.toString() ?? "N/A"),
                      _resultRow("Confidence",
                          "${((_xrayResult!['confidence'] ?? 0) * 100).toStringAsFixed(1)}%"),
                      _resultRow("Explanation",
                          _xrayResult!['explanation']?.toString() ?? "N/A"),
                      if (_xrayResult!['recommendations'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Recommendations:",
                          style: TextStyle(
                            color: PaperclipTheme.foregroundDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _xrayResult!['recommendations']?.toString() ?? "",
                          style: TextStyle(
                              color: PaperclipTheme.mutedDark, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PaperclipTheme.accentAmber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: PaperclipTheme.accentAmber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber,
                                color: PaperclipTheme.accentAmber, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "⚠️ Not a diagnosis. Consult a healthcare professional.",
                                style: TextStyle(
                                  color: PaperclipTheme.accentAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      case "EHR Assistant":
        return _panel(
          "EHR Assistant",
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_shared,
                  size: 64, color: PaperclipTheme.accentPurple),
              const SizedBox(height: 20),
              const Text(
                "FHIR-compatible EHR function calling with safety guardrails",
                style: TextStyle(
                  color: PaperclipTheme.foregroundDark,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    output = "Connecting to EHR system...";
                  });
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text("CONNECT EHR"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        );

      case "Homework Grader":
        return _panel(
          "Homework Grader",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Upload homework for OCR + rubric-based evaluation",
                style: TextStyle(
                  color: PaperclipTheme.foregroundDark,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isGradingHomework ? null : _uploadAndGradeHomework,
                icon: _isGradingHomework
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label:
                    Text(_isGradingHomework ? "GRADING..." : "UPLOAD HOMEWORK"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              if (_homeworkResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PaperclipTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PaperclipTheme.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in,
                              color: PaperclipTheme.accentGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Grading Results",
                            style: TextStyle(
                              color: PaperclipTheme.foregroundDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _resultRow("Score",
                          "${((_homeworkResult!['score'] ?? 0) * 100).toStringAsFixed(1)}%"),
                      _resultRow("Subject",
                          _homeworkResult!['subject']?.toString() ?? "N/A"),
                      _resultRow("Grade Level",
                          "${_homeworkResult!['grade_level'] ?? "N/A"}"),
                      if (_homeworkResult!['feedback'] != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Feedback:",
                          style: TextStyle(
                            color: PaperclipTheme.foregroundDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _homeworkResult!['feedback']?.toString() ?? "",
                          style: TextStyle(
                              color: PaperclipTheme.mutedDark, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      case "Quiz Generator":
        return _panel(
          "Quiz Generator",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Generate adaptive quizzes with cultural relevance",
                style: TextStyle(
                  color: PaperclipTheme.foregroundDark,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isGeneratingQuiz ? null : _generateQuiz,
                icon: _isGeneratingQuiz
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label:
                    Text(_isGeneratingQuiz ? "GENERATING..." : "GENERATE QUIZ"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              if (_quizResult != null && _quizResult!['quiz'] != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PaperclipTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PaperclipTheme.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.quiz,
                              color: PaperclipTheme.accentAmber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Quiz Generated",
                            style: TextStyle(
                              color: PaperclipTheme.foregroundDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      _resultRow("Topic",
                          _quizResult!['quiz']?['topic']?.toString() ?? "N/A"),
                      _resultRow("Questions",
                          "${_quizResult!['quiz']?['questions']?.length ?? 0}"),
                      _resultRow("Grade Level",
                          "${_quizResult!['quiz']?['grade_level'] ?? "N/A"}"),
                      if (_quizResult!['quiz']?['questions'] != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Questions:",
                          style: TextStyle(
                            color: PaperclipTheme.foregroundDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(List.generate(
                          (_quizResult!['quiz']?['questions']?.length ?? 0)
                              .clamp(0, 3),
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              "${i + 1}. ${_quizResult!['quiz']?['questions'][i]['question'] ?? ""}",
                              style: TextStyle(
                                  color: PaperclipTheme.mutedDark, fontSize: 12),
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _featureCard(String title, String description, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaperclipTheme.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaperclipTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PaperclipTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 32, color: PaperclipTheme.accentCyan),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PaperclipTheme.foregroundDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: PaperclipTheme.mutedDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryCard(
      String label, String value, String subtitle, int percentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaperclipTheme.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaperclipTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: PaperclipTheme.mutedDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: PaperclipTheme.foregroundDark,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: PaperclipTheme.mutedFgDark,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: PaperclipTheme.borderDark,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(PaperclipTheme.accentCyan),
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
        color: PaperclipTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaperclipTheme.borderDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForTab(title),
                color: PaperclipTheme.accentCyan,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: PaperclipTheme.foregroundDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: PaperclipTheme.borderDark, height: 1),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }

  // 🔹 SIDEBAR BUTTON - LM Studio Style
  Widget _sideButton(String text, IconData icon, {bool isCategory = false}) {
    final isSelected = selectedTab == text;
    return GestureDetector(
      onTap: () {
        if (text == "Health Track" ||
            text == "X-Ray Analysis" ||
            text == "EHR Assistant") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HealthScreen()),
          );
        } else if (text == "Education Track" ||
            text == "Homework Grader" ||
            text == "Quiz Generator") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EducationScreen()),
          );
        } else {
          switchTab(text);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCategory
              ? PaperclipTheme.surfaceDark.withValues(alpha: 0.3)
              : (isSelected ? PaperclipTheme.surfaceDark : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: PaperclipTheme.borderDark, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isCategory
                  ? PaperclipTheme.accentPurple
                  : (isSelected
                      ? PaperclipTheme.accentCyan
                      : PaperclipTheme.mutedDark),
              size: isCategory ? 16 : 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isCategory
                      ? PaperclipTheme.accentPurple
                      : (isSelected
                          ? PaperclipTheme.foregroundDark
                          : PaperclipTheme.mutedDark),
                  fontSize: isCategory ? 12 : 13,
                  fontWeight: isCategory
                      ? FontWeight.w700
                      : (isSelected ? FontWeight.w600 : FontWeight.w500),
                  letterSpacing: isCategory ? 0.5 : 0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                color: PaperclipTheme.mutedDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: PaperclipTheme.foregroundDark,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndAnalyzeXRay() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    setState(() {
      _isAnalyzingXRay = true;
      _xrayResult = null;
    });

    try {
      final response = await _healthEduService.analyzeXRay(
        imagePath: filePath,
        language: 'en',
      );

      setState(() {
        _xrayResult = response;
        output = "X-Ray analysis complete";
      });
    } catch (e) {
      setState(() {
        output = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isAnalyzingXRay = false;
      });
    }
  }

  Future<void> _uploadAndGradeHomework() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    setState(() {
      _isGradingHomework = true;
      _homeworkResult = null;
    });

    try {
      final response = await _healthEduService.gradeHomework(
        imagePath: filePath,
        subject: 'math',
        gradeLevel: 10,
        language: 'en',
      );

      setState(() {
        _homeworkResult = response;
        output = "Homework grading complete";
      });
    } catch (e) {
      setState(() {
        output = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isGradingHomework = false;
      });
    }
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _isGeneratingQuiz = true;
      _quizResult = null;
    });

    try {
      final response = await _healthEduService.generateQuiz(
        topic: 'Algebra',
        gradeLevel: 10,
        numQuestions: 5,
        language: 'en',
      );

      setState(() {
        _quizResult = response;
        output = "Quiz generated successfully";
      });
    } catch (e) {
      setState(() {
        output = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isGeneratingQuiz = false;
      });
    }
  }
}
