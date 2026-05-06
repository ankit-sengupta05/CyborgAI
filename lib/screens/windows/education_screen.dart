import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/health_edu_service.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen>
    with SingleTickerProviderStateMixin {
  final HealthEduService _eduService = HealthEduService();

  late TabController _tabController;
  int _currentTab = 0; // 0: Homework Grader, 1: Quiz Generator

  String? _selectedHomeworkPath;
  bool _isGrading = false;
  Map<String, dynamic>? _gradeResults;

  String _quizTopic = '';
  int _quizGradeLevel = 5;
  int _quizNumQuestions = 5;
  bool _isGeneratingQuiz = false;
  Map<String, dynamic>? _quizResults;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _rubricController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _culturalContextController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _rubricController.dispose();
    _topicController.dispose();
    _culturalContextController.dispose();
    super.dispose();
  }

  Future<void> _pickHomeworkFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedHomeworkPath = result.files.single.path!;
          _gradeResults = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _gradeHomework() async {
    if (_selectedHomeworkPath == null) {
      _showError('Please select homework image first');
      return;
    }

    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      _showError('Please enter subject name');
      return;
    }

    setState(() {
      _isGrading = true;
      _gradeResults = null;
    });

    try {
      final result = await _eduService.gradeHomework(
        imagePath: _selectedHomeworkPath!,
        subject: subject,
        gradeLevel: _quizGradeLevel,
        language: 'en',
      );

      setState(() {
        _gradeResults = result;
      });
    } catch (e) {
      _showError('Grading failed: $e');
    } finally {
      setState(() {
        _isGrading = false;
      });
    }
  }

  Future<void> _generateQuiz() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      _showError('Please enter a topic');
      return;
    }

    setState(() {
      _isGeneratingQuiz = true;
      _quizResults = null;
    });

    try {
      final result = await _eduService.generateQuiz(
        topic: topic,
        gradeLevel: _quizGradeLevel,
        numQuestions: _quizNumQuestions,
        culturalContext: _culturalContextController.text.trim().isEmpty
            ? null
            : _culturalContextController.text,
        language: 'en',
      );

      setState(() {
        _quizResults = result;
      });
    } catch (e) {
      _showError('Quiz generation failed: $e');
    } finally {
      setState(() {
        _isGeneratingQuiz = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              border:
                  Border(bottom: BorderSide(color: AppColors.borderDefault)),
            ),
            child: Row(
              children: [
                Icon(Icons.school, color: AppColors.accentPurple, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Education Track - Adaptive Tutor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'AI-powered grading & personalized quizzes (en, es, hi)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.accentPurple,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accentPurple,
            tabs: const [
              Tab(
                  icon: Icon(Icons.assignment_turned_in),
                  text: 'Homework Grader'),
              Tab(icon: Icon(Icons.quiz), text: 'Quiz Generator'),
            ],
          ),

          // Content
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildGraderTab(),
                _buildQuizTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload Section
          _buildUploadCard(),

          const SizedBox(height: 20),

          // Subject Input
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Subject',
              hintText: 'e.g., Mathematics, Science, English',
              prefixIcon: Icon(Icons.book_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Grade Level Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade Level: $_quizGradeLevel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Slider(
                value: _quizGradeLevel.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$_quizGradeLevel',
                onChanged: (value) {
                  setState(() {
                    _quizGradeLevel = value.toInt();
                  });
                },
                activeColor: AppColors.accentPurple,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Grade Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isGrading ? null : _gradeHomework,
              icon: _isGrading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.assignment_turned_in_outlined),
              label: Text(
                _isGrading ? 'Grading...' : 'Grade Homework',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Results
          if (_gradeResults != null) _buildGradeResults(),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          Icon(
            _selectedHomeworkPath != null
                ? Icons.check_circle
                : Icons.upload_file,
            size: 64,
            color: _selectedHomeworkPath != null
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedHomeworkPath != null
                ? 'File Selected: ${_selectedHomeworkPath!.split('\\').last}'
                : 'Upload Homework Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedHomeworkPath != null
                ? 'Supports: JPG, PNG, PDF (OCR enabled)'
                : 'Supported formats: JPG, PNG, PDF',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickHomeworkFile,
            icon: Icon(Icons.folder_open_outlined),
            label: const Text('Browse Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppColors.success, size: 24),
              const SizedBox(width: 8),
              Text(
                'Grading Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(),
          if (_gradeResults!['score'] != null) ...[
            Row(
              children: [
                Text(
                  'Score: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                Text(
                  '${(_gradeResults!['score'] * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_gradeResults!['feedback'] != null) ...[
            Text(
              'Feedback:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _gradeResults!['feedback'],
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_gradeResults!['strengths'] != null) ...[
            Text(
              'Strengths:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _gradeResults!['strengths'],
              style: TextStyle(color: AppColors.success),
            ),
            const SizedBox(height: 16),
          ],
          if (_gradeResults!['areas_for_improvement'] != null) ...[
            Text(
              'Areas for Improvement:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _gradeResults!['areas_for_improvement'],
              style: TextStyle(color: AppColors.accentOrange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Input
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              labelText: 'Topic',
              hintText: 'e.g., Photosynthesis, World War II, Fractions',
              prefixIcon: Icon(Icons.topic_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Grade Level Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grade Level: $_quizGradeLevel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Slider(
                value: _quizGradeLevel.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$_quizGradeLevel',
                onChanged: (value) {
                  setState(() {
                    _quizGradeLevel = value.toInt();
                  });
                },
                activeColor: AppColors.accentPurple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Number of Questions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Number of Questions: $_quizNumQuestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Slider(
                value: _quizNumQuestions.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_quizNumQuestions',
                onChanged: (value) {
                  setState(() {
                    _quizNumQuestions = value.toInt();
                  });
                },
                activeColor: AppColors.accentOrange,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Cultural Context (Optional)
          TextField(
            controller: _culturalContextController,
            decoration: InputDecoration(
              labelText: 'Cultural Context (optional)',
              hintText: 'e.g., Indian curriculum, US Common Core',
              prefixIcon: Icon(Icons.public_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingQuiz ? null : _generateQuiz,
              icon: _isGeneratingQuiz
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.auto_awesome_outlined),
              label: Text(
                _isGeneratingQuiz ? 'Generating...' : 'Generate Quiz',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Results
          if (_quizResults != null) _buildQuizResults(),

          const SizedBox(height: 20),

          // Multi-language Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentPurple),
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: AppColors.accentPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Multi-Language Support',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentPurple,
                        ),
                      ),
                      Text(
                        'Available in English, Spanish (es), and Hindi (hi)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz, color: AppColors.accentOrange, size: 24),
              const SizedBox(width: 8),
              Text(
                'Generated Quiz',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(),
          if (_quizResults!['questions'] != null) ...[
            Text(
              'Questions:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Display questions list
            ...(_quizResults!['questions'] as List)
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key + 1;
              final question = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q$index. ${question['question'] ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (question['options'] != null) ...[
                      const SizedBox(height: 8),
                      ...(question['options'] as List).map((option) => Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text(
                              '• $option',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )),
                    ],
                    if (question['answer'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Answer: ${question['answer']}',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
          if (_quizResults!['difficulty_adaptation'] != null) ...[
            const SizedBox(height: 16),
            Text(
              'Difficulty Adaptation: ${_quizResults!['difficulty_adaptation']}',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
