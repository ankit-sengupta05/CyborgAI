import 'dart:io' if (dart.library.html) 'package:cyborg/core/services/io_stubs.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';

/// Health Track API Service
/// Communicates with /api/v1/health/* endpoints
class HealthApiService {
  static final HealthApiService _instance = HealthApiService._internal();
  factory HealthApiService() => _instance;
  HealthApiService._internal();

  final Dio _dio = apiDio;

  /// Check health service availability
  Future<Map<String, dynamic>> getStatus() async {
    final resp = await _dio.get('health/status');
    return resp.data as Map<String, dynamic>;
  }

  /// Get demo configuration (supported languages, symptoms, etc.)
  Future<Map<String, dynamic>> getDemoConfig() async {
    final resp = await _dio.get('health/demo-config');
    return resp.data as Map<String, dynamic>;
  }

  /// Analyze a chest X-ray image
  /// [imageFile] — the PNG/JPG file
  /// [age] — optional patient age
  /// [symptoms] — comma-separated symptom list
  /// [language] — language code (en, es, hi)
  Future<Map<String, dynamic>> analyzeXray({
    required File imageFile,
    int? age,
    String? symptoms,
    String language = 'en',
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
      if (age != null) 'age': age,
      if (symptoms != null) 'symptoms': symptoms,
      'language': language,
    });

    final resp = await _dio.post(
      'health/analyze-xray',
      data: formData,
      options: Options(
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Query EHR for patient data
  Future<Map<String, dynamic>> queryEhr({
    required String patientId,
    String queryType = 'summary',
    String? dateRange,
  }) async {
    final formData = FormData.fromMap({
      'patient_id': patientId,
      'query_type': queryType,
      if (dateRange != null) 'date_range': dateRange,
    });

    final resp = await _dio.post('health/ehr/query', data: formData);
    return resp.data as Map<String, dynamic>;
  }
}
