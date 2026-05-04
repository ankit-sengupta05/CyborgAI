import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';

class HomeMobile extends StatefulWidget {
  _HomeMobile createState() => _HomeMobile();
}

class _HomeMobile extends State<HomeMobile> {
  String selectedTab = "Neural Interface";
  String output = "System Ready...";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundMain,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done,
                    color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                const Text(
                  "Online",
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
      body: Column(
        children: [
          // Tab Selector
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _tabChip("Neural Interface", Icons.psychology),
                _tabChip("Devices", Icons.devices),
                _tabChip("GPU", Icons.memory),
                const SizedBox(width: 8),
                _categoryChip("Health", Icons.medical_services),
                _tabChip("X-Ray", Icons.add_chart),
                _tabChip("EHR", Icons.folder_shared),
                const SizedBox(width: 8),
                _categoryChip("Education", Icons.school),
                _tabChip("Grader", Icons.assignment_turned_in),
                _tabChip("Quiz", Icons.quiz),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, IconData icon) {
    final isSelected = selectedTab == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        onSelected: (_) => setState(() => selectedTab = label),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppColors.accentBlue
                    : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
          ],
        ),
        selectedColor: AppColors.backgroundSurface,
        checkmarkColor: AppColors.accentBlue,
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        onSelected: (_) => setState(() => selectedTab = "$label Track"),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accentPurple),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accentPurple,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: AppColors.backgroundSurface.withOpacity(0.3),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedTab) {
      case "Neural Interface":
        return Center(
          child: Text(output,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        );
      case "Health Track":
        return _mobileFeatureCard(
          "🏥 Medical AI",
          "MedGemma 4B X-ray analysis",
          Icons.medical_services,
          () => setState(() => output = "Launching X-Ray Demo..."),
        );
      case "X-Ray":
        return _mobileActionCard(
          "X-Ray Analysis",
          "Upload chest X-ray",
          Icons.add_chart,
          "UPLOAD X-RAY",
        );
      case "EHR":
        return _mobileActionCard(
          "EHR Assistant",
          "FHIR-compatible EHR",
          Icons.folder_shared,
          "CONNECT EHR",
        );
      case "Education Track":
        return _mobileFeatureCard(
          "📚 Adaptive Tutor",
          "Multilingual grading (en, es, hi)",
          Icons.school,
          () => setState(() => output = "Launching Grader Demo..."),
        );
      case "Grader":
        return _mobileActionCard(
          "Homework Grader",
          "OCR + rubric evaluation",
          Icons.assignment_turned_in,
          "UPLOAD HOMEWORK",
        );
      case "Quiz":
        return _mobileActionCard(
          "Quiz Generator",
          "Adaptive quizzes",
          Icons.quiz,
          "GENERATE QUIZ",
        );
      default:
        return Center(
          child: Text(output,
              style: const TextStyle(color: AppColors.textPrimary)),
        );
    }
  }

  Widget _mobileFeatureCard(
      String title, String desc, IconData icon, VoidCallback onTap) {
    return Card(
      color: AppColors.surfaceVariant,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.accentBlue, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(desc,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onTap,
                child: const Text("LAUNCH DEMO"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileActionCard(
      String title, String desc, IconData icon, String btnLabel) {
    return Center(
      child: Card(
        color: AppColors.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accentBlue, size: 56),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(desc,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => output = "$btnLabel pressed"),
                icon: const Icon(Icons.play_arrow),
                label: Text(btnLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
