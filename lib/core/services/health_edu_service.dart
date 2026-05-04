import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

/// Service for Health & Education Gemma 4 features
class HealthEduService {
  static final HealthEduService _instance = HealthEduService._internal();
  factory HealthEduService() => _instance;

  final Dio _dio = ApiService().dio;

  HealthEduService._internal();

  // ===========================================================================
  // HEALTH TRACK
  // ===========================================================================

  /// Check health service availability
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final response = await _dio.get(ApiConstants.healthStatus);
      return response.data;
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  /// Analyze chest X-ray image
  Future<Map<String, dynamic>> analyzeXRay({
    required String imagePath,
    int? age,
    String? symptoms,
    String language = 'en',
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
        if (age != null) 'age': age,
        if (symptoms != null) 'symptoms': symptoms,
        'language': language,
      });

      final response = await _dio.post(
        ApiConstants.healthAnalyzeXray,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 5)),
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Query EHR data
  Future<Map<String, dynamic>> queryEHR({
    required String patientId,
    String queryType = 'summary',
    String? dateRange,
  }) async {
    try {
      final formData = FormData.fromMap({
        'patient_id': patientId,
        'query_type': queryType,
        if (dateRange != null) 'date_range': dateRange,
      });

      final response = await _dio.post(
        ApiConstants.healthEHRQuery,
        data: formData,
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update EHR record
  Future<Map<String, dynamic>> updateEHR({
    required String patientId,
    required String updateType,
    required Map<String, dynamic> data,
  }) async {
    try {
      final formData = FormData.fromMap({
        'patient_id': patientId,
        'update_type': updateType,
        'data': jsonEncode(data),
      });

      final response = await _dio.post(
        ApiConstants.healthEHRUpdate,
        data: formData,
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get health demo configuration
  Future<Map<String, dynamic>> getHealthDemoConfig() async {
    try {
      final response = await _dio.get(ApiConstants.healthDemoConfig);
      return response.data;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ===========================================================================
  // EDUCATION TRACK
  // ===========================================================================

  /// Check education service availability
  Future<Map<String, dynamic>> getEducationStatus() async {
    try {
      final response = await _dio.get(ApiConstants.educationStatus);
      return response.data;
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  /// Grade homework submission
  Future<Map<String, dynamic>> gradeHomework({
    required String imagePath,
    required String subject,
    required int gradeLevel,
    Map<String, dynamic>? rubric,
    String language = 'en',
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
        'subject': subject,
        'grade_level': gradeLevel,
        if (rubric != null) 'rubric': jsonEncode(rubric),
        'language': language,
      });

      final response = await _dio.post(
        ApiConstants.educationGradeHomework,
        data: formData,
        options: Options(sendTimeout: const Duration(minutes: 3)),
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generate adaptive quiz
  Future<Map<String, dynamic>> generateQuiz({
    required String topic,
    required int gradeLevel,
    int numQuestions = 5,
    List<String>? questionTypes,
    String? culturalContext,
    String language = 'en',
  }) async {
    try {
      final formData = FormData.fromMap({
        'topic': topic,
        'grade_level': gradeLevel,
        'num_questions': numQuestions,
        if (questionTypes != null) 'question_types': questionTypes.join(','),
        if (culturalContext != null) 'cultural_context': culturalContext,
        'language': language,
      });

      final response = await _dio.post(
        ApiConstants.educationGenerateQuiz,
        data: formData,
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get student progress
  Future<Map<String, dynamic>> getStudentProgress(String studentId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.educationProgress}/$studentId',
      );
      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Track quiz submission
  Future<Map<String, dynamic>> trackSubmission({
    required String studentId,
    required String quizId,
    required Map<String, dynamic> answers,
    required double score,
    required int timeSpent,
  }) async {
    try {
      final formData = FormData.fromMap({
        'student_id': studentId,
        'quiz_id': quizId,
        'answers': jsonEncode(answers),
        'score': score,
        'time_spent': timeSpent,
      });

      final response = await _dio.post(
        ApiConstants.educationTrackSubmission,
        data: formData,
      );

      return response.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get education demo configuration
  Future<Map<String, dynamic>> getEducationDemoConfig() async {
    try {
      final response = await _dio.get(ApiConstants.educationDemoConfig);
      return response.data;
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
