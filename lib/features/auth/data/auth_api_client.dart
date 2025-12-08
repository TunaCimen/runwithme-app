import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/auth_dto.dart';

/// API client for authentication endpoints
class AuthApiClient {
  final Dio _dio;

  AuthApiClient({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ));

  /// Register a new user
  /// Returns RegisterResponseDto indicating email verification is required
  Future<RegisterResponseDto> register(RegisterRequestDto request) async {
    final response = await _dio.post(
      '/api/v1/auth/register',
      data: request.toJson(),
    );
    return RegisterResponseDto.fromJson(_decodeResponse(response.data));
  }

  /// Resend verification email
  Future<EmailVerificationResponseDto> resendVerificationEmail(String email) async {
    final response = await _dio.post(
      '/api/v1/auth/resend-verification',
      data: {'email': email},
    );
    return EmailVerificationResponseDto.fromJson(_decodeResponse(response.data));
  }

  /// Get user email by username (for resend verification flow)
  Future<String?> getEmailByUsername(String username) async {
    try {
      final response = await _dio.get('/api/v1/users/username/$username');
      final data = _decodeResponse(response.data);
      return data['email'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Login with username and password
  Future<AuthResponseDto> login(LoginRequestDto request) async {
    final response = await _dio.post(
      '/api/v1/auth/login',
      data: request.toJson(),
    );
    return AuthResponseDto.fromJson(_decodeResponse(response.data));
  }

  /// Refresh access token using refresh token
  Future<AuthResponseDto> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      '/api/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthResponseDto.fromJson(_decodeResponse(response.data));
  }

  /// Logout (invalidate tokens on server)
  Future<void> logout(String accessToken) async {
    await _dio.post(
      '/api/v1/auth/logout',
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw FormatException('Unexpected response format');
  }
}
