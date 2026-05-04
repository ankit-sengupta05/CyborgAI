import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_constants.dart';

/// Singleton Dio instance that auto-attaches Firebase ID token to every request.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;

  ApiService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 300),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ensure base URL is always up to date
        options.baseUrl = ApiConstants.baseUrl;

        // Attach Firebase ID token if user is signed in
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
        } catch (_) {
          // If auth fails, continue without token (backend will 401)
        }
        handler.next(options);
      },
      onError: (err, handler) {
        // Don't crash on network errors — return them to caller
        handler.next(err);
      },
    ));
  }
}

/// Convenience getter for the authenticated Dio instance
Dio get apiDio => ApiService().dio;
