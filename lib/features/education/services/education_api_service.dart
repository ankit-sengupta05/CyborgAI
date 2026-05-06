import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';

/// Education Track API Service
/// Communicates with /api/v1/education/* endpoints
class EducationApiService {
  static final EducationApiService _instance = EducationApiService._internal();
  factory EducationApiService() => _instance;
  EducationApiService._internal();

  final Dio _dio = apiDio;

  /// Check education service availability
  Future<Map<String, dynamic>> getStatus() async {
    final resp = await _dio.get('/api/v1/education/status');
    return resp.data as Map<String, dynamic>;
  }

  /// Get demo configuration
  Future<Map<String, dynamic>> getDemoConfig() async {
    final resp = await _dio.get('/api/v1/education/demo-config');
    return resp.data as Map<String, dynamic>;
  }

  /// Grade a homework image
  /// [imageFile] — homework photo
  /// [subject] — math, science, english, history
  /// [gradeLevel] — 1-12
  /// [language] — en, es, hi
  Future<Map<String, dynamic>> gradeHomework({
    required File imageFile,
    required String subject,
    required int gradeLevel,
    String language = 'en',
    String? rubric,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
      'subject': subject,
      'grade_level': gradeLevel,
      'language': language,
      if (rubric != null) 'rubric': rubric,
    });

    final resp = await _dio.post(
      '/api/v1/education/grade-homework',
      data: formData,
      options: Options(
        receiveTimeout: const Duration(seconds: 120),
        contentType: 'multipart/form-data',
      ),
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Generate an adaptive quiz
  Future<Map<String, dynamic>> generateQuiz({
    required String topic,
    required int gradeLevel,
    int numQuestions = 5,
    String questionTypes = 'multiple_choice',
    String language = 'en',
    String? culturalContext,
  }) async {
    final formData = FormData.fromMap({
      'topic': topic,
      'grade_level': gradeLevel,
      'num_questions': numQuestions,
      'question_types': questionTypes,
      'language': language,
      if (culturalContext != null) 'cultural_context': culturalContext,
    });

    final resp = await _dio.post(
      '/api/v1/education/generate-quiz',
      data: formData,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Get student progress
  Future<Map<String, dynamic>> getProgress(String studentId) async {
    final resp = await _dio.get('/api/v1/education/progress/$studentId');
    return resp.data as Map<String, dynamic>;
  }

  /// Track a quiz submission
  Future<Map<String, dynamic>> trackSubmission({
    required String studentId,
    required String quizId,
    required Map<String, dynamic> answers,
    required double score,
    required int timeSpent,
  }) async {
    final formData = FormData.fromMap({
      'student_id': studentId,
      'quiz_id': quizId,
      'answers': answers.toString(),
      'score': score,
      'time_spent': timeSpent,
    });

    final resp = await _dio.post(
      '/api/v1/education/track-submission',
      data: formData,
    );
    return resp.data as Map<String, dynamic>;
  }
}
