import 'package:dio/dio.dart';

/// Base API client with common configuration
class BaseApiClient {
  final String baseUrl;
  late final Dio dio;

  BaseApiClient({
    required this.baseUrl,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 20),
    Map<String, dynamic>? headers,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        },
      ),
    );

    // Logging disabled to reduce console noise
    // Uncomment for debugging API calls:
    // dio.interceptors.add(LogInterceptor(
    //   requestBody: true,
    //   responseBody: true,
    //   error: true,
    //   logPrint: (obj) => print('[API] $obj'),
    // ));
  }

  /// Add authorization header
  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Remove authorization header
  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }
}
