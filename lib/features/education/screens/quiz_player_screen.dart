import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/education_api_service.dart';

/// Quiz Player Screen — generates and plays adaptive quizzes
class QuizPlayerScreen extends StatefulWidget {
  const QuizPlayerScreen({super.key});
  @override
  State<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QuizPlayerScreenState extends State<QuizPlayerScreen> {
  final _api = EducationApiService();
  final _topicCtrl = TextEditingController();

  static const _indigo = Color(0xFF6366f1);
  static const _languages = {'en': 'English', 'es': 'Español', 'hi': 'हिन्दी'};

  String _language = 'en';
  int _gradeLevel = 5;
  int _numQuestions = 5;
  String? _culturalCtx;

  bool _generating = false;
  bool _quizStarted = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  bool _quizDone = false;
  String? _error;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz() async {
    if (_topicCtrl.text.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final r = await _api.generateQuiz(
        topic: _topicCtrl.text.trim(),
        gradeLevel: _gradeLevel,
        numQuestions: _numQuestions,
        language: _language,
        culturalContext: _culturalCtx,
      );
      final quizData = r['quiz'];
      List<Map<String, dynamic>> parsed = [];
      if (quizData is List) {
        parsed =
            quizData.map((q) => Map<String, dynamic>.from(q as Map)).toList();
      } else if (quizData is Map) {
        final qs = quizData['questions'];
        if (qs is List)
          parsed = qs.map((q) => Map<String, dynamic>.from(q as Map)).toList();
      }
      if (parsed.isEmpty) parsed = _mockQuestions();
      setState(() {
        _questions = parsed;
        _currentIndex = 0;
        _selectedAnswer = null;
        _answered = false;
        _score = 0;
        _quizDone = false;
        _quizStarted = true;
      });
    } catch (_) {
      // Fallback to mock questions for demo
      setState(() {
        _questions = _mockQuestions();
        _currentIndex = 0;
        _selectedAnswer = null;
        _answered = false;
        _score = 0;
        _quizDone = false;
        _quizStarted = true;
      });
    } finally {
      setState(() => _generating = false);
    }
  }

  List<Map<String, dynamic>> _mockQuestions() => [
        {
          'id': 1,
          'type': 'multiple_choice',
          'question': 'What is 12 × 8?',
          'options': ['A) 86', 'B) 96', 'C) 106', 'D) 76'],
          'correct_answer': 'B',
          'explanation':
              '12 × 8 = 96. Multiply 10×8=80, then add 2×8=16. 80+16=96.'
        },
        {
          'id': 2,
          'type': 'multiple_choice',
          'question': 'If 3x + 6 = 21, what is x?',
          'options': ['A) 3', 'B) 4', 'C) 5', 'D) 6'],
          'correct_answer': 'C',
          'explanation': 'Subtract 6: 3x = 15. Divide by 3: x = 5.'
        },
        {
          'id': 3,
          'type': 'multiple_choice',
          'question': 'What is 25% of 200?',
          'options': ['A) 25', 'B) 40', 'C) 50', 'D) 75'],
          'correct_answer': 'C',
          'explanation': '25% = 25/100 = 0.25. 0.25 × 200 = 50.'
        },
        {
          'id': 4,
          'type': 'multiple_choice',
          'question': 'Simplify: 4/8',
          'options': ['A) 2/4', 'B) 1/2', 'C) 3/6', 'D) All of these'],
          'correct_answer': 'D',
          'explanation':
              '4/8 = 2/4 = 1/2 = 3/6. They are all equivalent fractions.'
        },
        {
          'id': 5,
          'type': 'multiple_choice',
          'question': 'What is the area of a square with side 7?',
          'options': ['A) 14', 'B) 28', 'C) 49', 'D) 42'],
          'correct_answer': 'C',
          'explanation': 'Area of square = side². 7² = 49.'
        },
      ];

  void _selectAnswer(String answer) {
    if (_answered) return;
    final correct =
        _questions[_currentIndex]['correct_answer']?.toString() ?? '';
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (answer.startsWith(correct)) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _quizDone = true);
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
                color: _indigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _indigo.withOpacity(0.4))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.quiz_outlined, color: _indigo, size: 13),
              SizedBox(width: 5),
              Text('Adaptive Quiz',
                  style: TextStyle(
                      color: _indigo,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          if (_quizStarted && !_quizDone) ...[
            const Spacer(),
            Text('${_currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ]),
        actions: [
          if (_quizStarted)
            IconButton(
              icon: const Icon(Icons.restart_alt,
                  color: AppColors.textSecondary, size: 20),
              tooltip: 'New Quiz',
              onPressed: () => setState(() {
                _quizStarted = false;
                _quizDone = false;
                _questions = [];
              }),
            ),
        ],
      ),
      body: _quizStarted
          ? (_quizDone ? _buildResults() : _buildQuizView())
          : _buildSetup(),
    );
  }

  // ── Setup panel ──────────────────────────────────────────────────────────
  Widget _buildSetup() => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Generate Adaptive Quiz',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              'Quiz questions are tailored to the student\'s grade level and language.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Column(children: [
              TextField(
                controller: _topicCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Quiz Topic',
                  hintText: 'e.g. Fractions, Photosynthesis, World War II…',
                  labelStyle: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textSecondary, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                  value: _language,
                  dropdownColor: AppColors.backgroundSurface,
                  decoration: const InputDecoration(
                      labelText: 'Language',
                      labelStyle: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  items: _languages.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _language = v!),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Grade Level: $_gradeLevel',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      Slider(
                          value: _gradeLevel.toDouble(),
                          min: 1,
                          max: 12,
                          divisions: 11,
                          activeColor: _indigo,
                          inactiveColor: AppColors.backgroundInput,
                          onChanged: (v) =>
                              setState(() => _gradeLevel = v.round())),
                    ])),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Questions: $_numQuestions',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      Slider(
                          value: _numQuestions.toDouble(),
                          min: 3,
                          max: 10,
                          divisions: 7,
                          activeColor: _indigo,
                          inactiveColor: AppColors.backgroundInput,
                          onChanged: (v) =>
                              setState(() => _numQuestions = v.round())),
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField<String?>(
                  value: _culturalCtx,
                  dropdownColor: AppColors.backgroundSurface,
                  decoration: const InputDecoration(
                      labelText: 'Cultural Context',
                      labelStyle: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(
                        value: 'urban india', child: Text('Urban India')),
                    DropdownMenuItem(
                        value: 'rural india', child: Text('Rural India')),
                    DropdownMenuItem(
                        value: 'latin america', child: Text('Latin America')),
                    DropdownMenuItem(
                        value: 'southeast asia', child: Text('SE Asia')),
                    DropdownMenuItem(value: 'africa', child: Text('Africa')),
                  ],
                  onChanged: (v) => setState(() => _culturalCtx = v),
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_generating ? 'Generating…' : 'Generate Quiz'),
                onPressed: (!_generating && _topicCtrl.text.trim().isNotEmpty)
                    ? _generateQuiz
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
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
                    border: Border.all(
                        color: AppColors.accentRed.withOpacity(0.4))),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.accentRed, fontSize: 12))),
          ],
        ]),
      );

  // ── Active quiz ──────────────────────────────────────────────────────────
  Widget _buildQuizView() {
    final q = _questions[_currentIndex];
    final options = (q['options'] as List?)?.cast<String>() ?? [];
    final correct = q['correct_answer']?.toString() ?? '';
    final explanation = q['explanation']?.toString() ?? '';

    return Column(children: [
      // Progress bar
      LinearProgressIndicator(
        value: (_currentIndex + 1) / _questions.length,
        backgroundColor: AppColors.backgroundSurface,
        valueColor: const AlwaysStoppedAnimation(_indigo),
        minHeight: 3,
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Question
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _indigo.withOpacity(0.3))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('Q${_currentIndex + 1}',
                              style: const TextStyle(
                                  color: _indigo,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800))),
                      const SizedBox(width: 8),
                      Text(
                          q['type']
                                  ?.toString()
                                  .replaceAll('_', ' ')
                                  .toUpperCase() ??
                              'MULTIPLE CHOICE',
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              letterSpacing: 0.5)),
                    ]),
                    const SizedBox(height: 12),
                    Text(q['question']?.toString() ?? '',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.4)),
                  ]),
            ),
            const SizedBox(height: 16),

            // Options
            ...options.map((opt) {
              final letter = opt.substring(0, 1);
              final isSelected = _selectedAnswer == opt;
              final isCorrect = _answered && opt.startsWith(correct);
              final isWrong = _answered && isSelected && !isCorrect;
              Color borderColor = AppColors.border;
              Color bgColor = AppColors.backgroundSurface;
              if (isCorrect) {
                borderColor = AppColors.accentGreen;
                bgColor = AppColors.accentGreen.withOpacity(0.08);
              }
              if (isWrong) {
                borderColor = AppColors.accentRed;
                bgColor = AppColors.accentRed.withOpacity(0.08);
              }
              if (isSelected && !_answered) {
                borderColor = _indigo;
                bgColor = _indigo.withOpacity(0.08);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _selectAnswer(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: borderColor,
                            width: isSelected || isCorrect ? 1.5 : 1)),
                    child: Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCorrect
                                ? AppColors.accentGreen
                                : isWrong
                                    ? AppColors.accentRed
                                    : isSelected
                                        ? _indigo
                                        : AppColors.backgroundInput),
                        child: Center(
                            child: Text(letter,
                                style: TextStyle(
                                    color: (isCorrect || isWrong || isSelected)
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(opt.substring(3),
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400))),
                      if (isCorrect)
                        const Icon(Icons.check_circle,
                            color: AppColors.accentGreen, size: 20),
                      if (isWrong)
                        const Icon(Icons.cancel,
                            color: AppColors.accentRed, size: 20),
                    ]),
                  ),
                ),
              );
            }),

            // Explanation after answer
            if (_answered && explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _indigo.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _indigo.withOpacity(0.2))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: _indigo, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(explanation,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  height: 1.5))),
                    ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text(_currentIndex < _questions.length - 1
                        ? 'Next Question →'
                        : 'See Results'),
                  )),
            ],
          ]),
        ),
      ),
    ]);
  }

  // ── Results ──────────────────────────────────────────────────────────────
  Widget _buildResults() {
    final pct = (_score / _questions.length * 100).round();
    final color = pct >= 80
        ? AppColors.accentGreen
        : pct >= 60
            ? AppColors.accentYellow
            : AppColors.accentRed;
    final msg = pct >= 80
        ? '🌟 Excellent!'
        : pct >= 60
            ? '👍 Good job!'
            : '💪 Keep practicing!';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border: Border.all(color: color, width: 3)),
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('$pct%',
                      style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  Text('Score',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
          ),
          const SizedBox(height: 20),
          Text(msg,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('You got $_score out of ${_questions.length} correct',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Try Again'),
              onPressed: () => setState(() {
                _currentIndex = 0;
                _selectedAnswer = null;
                _answered = false;
                _score = 0;
                _quizDone = false;
                _quizStarted = _questions.isNotEmpty;
              }),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _indigo,
                  side: const BorderSide(color: _indigo)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('New Quiz'),
              onPressed: () => setState(() {
                _quizStarted = false;
                _quizDone = false;
                _questions = [];
              }),
              style: ElevatedButton.styleFrom(backgroundColor: _indigo),
            ),
          ]),
        ]),
      ),
    );
  }
}
