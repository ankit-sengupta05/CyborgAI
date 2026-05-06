import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../services/education_api_service.dart';

/// Homework Scanner Screen
/// Capture/upload a homework photo, select subject + grade, and receive AI grading
class HomeworkScannerScreen extends StatefulWidget {
  const HomeworkScannerScreen({super.key});
  @override
  State<HomeworkScannerScreen> createState() => _HomeworkScannerScreenState();
}

class _HomeworkScannerScreenState extends State<HomeworkScannerScreen> {
  final _api = EducationApiService();
  File? _image;
  bool _grading = false;
  Map<String, dynamic>? _result;
  String _subject = 'math';
  int _gradeLevel = 5;
  String _language = 'en';
  String? _error;

  static const _eduViolet = Color(0xFF8B5CF6);
  static const _subjects = [
    'math',
    'science',
    'english',
    'history',
    'geography'
  ];
  static const _languages = {'en': 'English', 'es': 'Español', 'hi': 'हिन्दी'};

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _image = File(result.files.single.path!);
      _result = null;
      _error = null;
    });
  }

  Future<void> _grade() async {
    if (_image == null) return;
    setState(() {
      _grading = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await _api.gradeHomework(
          imageFile: _image!,
          subject: _subject,
          gradeLevel: _gradeLevel,
          language: _language);
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _grading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundMain,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _eduViolet.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _eduViolet.withOpacity(0.4))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_outlined, color: _eduViolet, size: 13),
              SizedBox(width: 5),
              Text('Homework Grader',
                  style: TextStyle(
                      color: _eduViolet,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      body: Row(children: [
        SizedBox(width: 340, child: _buildLeft()),
        Container(width: 1, color: AppColors.border),
        Expanded(child: _result != null ? _buildResults() : _buildEmpty()),
      ]),
    );
  }

  Widget _buildLeft() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Image upload
          GestureDetector(
            onTap: _pick,
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _image != null
                        ? _eduViolet.withOpacity(0.5)
                        : AppColors.border),
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: kIsWeb
                          ? Image.network(_image!.path, fit: BoxFit.contain)
                          : Image.file(_image! as dynamic, fit: BoxFit.contain))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(Icons.photo_camera_outlined,
                              color: AppColors.textMuted, size: 40),
                          const SizedBox(height: 8),
                          Text('Tap to upload homework photo',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          Text('PNG, JPG supported',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ]),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                label: Text(_image != null ? 'Change Photo' : 'Select Photo'),
                onPressed: _pick,
                style: OutlinedButton.styleFrom(
                    foregroundColor: _eduViolet,
                    side: const BorderSide(color: _eduViolet)),
              )),
          const SizedBox(height: 14),

          // Settings
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Assignment Settings',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _subject,
                dropdownColor: AppColors.backgroundSurface,
                decoration: const InputDecoration(
                    labelText: 'Subject',
                    labelStyle: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                items: _subjects
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1))))
                    .toList(),
                onChanged: (v) => setState(() => _subject = v!),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text('Grade Level: ',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                Text('$_gradeLevel',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
              Slider(
                value: _gradeLevel.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                activeColor: _eduViolet,
                inactiveColor: AppColors.backgroundInput,
                label: 'Grade $_gradeLevel',
                onChanged: (v) => setState(() => _gradeLevel = v.round()),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _language,
                dropdownColor: AppColors.backgroundSurface,
                decoration: const InputDecoration(
                    labelText: 'Feedback Language',
                    labelStyle: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                items: _languages.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _language = v!),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _grading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.grading_outlined, size: 17),
                label: Text(_grading ? 'Grading...' : 'Grade Homework'),
                onPressed: (_image != null && !_grading) ? _grade : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _eduViolet,
                    disabledBackgroundColor: AppColors.backgroundInput,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.accentRed.withOpacity(0.4))),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: AppColors.accentRed, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.accentRed, fontSize: 12)))
              ]),
            ),
          ],
        ]),
      );

  Widget _buildEmpty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: _eduViolet.withOpacity(0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: _eduViolet.withOpacity(0.3), width: 2)),
            child:
                const Icon(Icons.school_outlined, color: _eduViolet, size: 44)),
        const SizedBox(height: 18),
        Text('Adaptive Homework Grader',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            'Upload a homework photo to receive AI grading\nwith constructive feedback in your language',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center),
      ]));

  Widget _buildResults() {
    final r = _result!;
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final scoreColor = score >= 80
        ? AppColors.accentGreen
        : score >= 60
            ? AppColors.accentYellow
            : AppColors.accentRed;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.grading_outlined, color: _eduViolet, size: 20),
          const SizedBox(width: 8),
          Text('Grading Results',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),

        // Score
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scoreColor.withOpacity(0.4))),
          child: Row(children: [
            Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withOpacity(0.12),
                    border: Border.all(color: scoreColor, width: 2)),
                child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text('$score',
                          style: TextStyle(
                              color: scoreColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text('/100',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 10)),
                    ]))),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      score >= 80
                          ? '🌟 Excellent work!'
                          : score >= 60
                              ? '👍 Good effort!'
                              : '💪 Keep practicing!',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${r['subject'] ?? _subject} · Grade ${r['grade_level'] ?? _gradeLevel}',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: AppColors.backgroundInput,
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 5),
                ])),
          ]),
        ),
        const SizedBox(height: 14),

        // Feedback
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _eduViolet.withOpacity(0.3))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.feedback_outlined, color: _eduViolet, size: 15),
              const SizedBox(width: 6),
              Text('Feedback',
                  style: TextStyle(
                      color: _eduViolet,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5))
            ]),
            const SizedBox(height: 8),
            Text(r['feedback'] ?? 'No feedback available.',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, height: 1.6)),
          ]),
        ),

        // Remediation quiz if available
        if ((r['remediation_quiz'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF22c55e).withOpacity(0.3))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.quiz_outlined,
                    color: Color(0xFF22c55e), size: 15),
                const SizedBox(width: 6),
                const Text('Practice Quiz',
                    style: TextStyle(
                        color: Color(0xFF22c55e),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5))
              ]),
              const SizedBox(height: 8),
              ...(r['remediation_quiz'] as List).take(3).map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.backgroundMain,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            q['question']?.toString() ??
                                q['message']?.toString() ??
                                '',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                height: 1.5))),
                  )),
            ]),
          ),
        ],
      ]),
    );
  }
}
