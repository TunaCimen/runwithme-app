import 'package:dio/dio.dart';
import '../../../core/models/user.dart';
import 'auth_api_client.dart';
import 'models/auth_dto.dart';

/// Repository for authentication operations
class AuthRepository {
  final AuthApiClient _apiClient;

  AuthRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    AuthApiClient? apiClient,
  }) : _apiClient = apiClient ?? AuthApiClient(baseUrl: baseUrl);

  /// Register a new user
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 [AUTH_REPO] Attempting registration for: $email');

      final request = RegisterRequestDto(
        username: username,
        email: email,
        password: password,
      );

      final response = await _apiClient.register(request);

      print('✅ [AUTH_REPO] Registration successful for user: ${response.user.username}');

      return AuthResult.success(
        user: User(
          userId: response.user.userId,
          username: response.user.username,
          email: response.user.email,
          passwordHash: '',
          createdAt: DateTime.now(),
        ),
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        message: 'Account created successfully',
      );
    } on DioException catch (e) {
      return _handleDioException(e, 'Registration failed');
    } catch (e) {
      print('🔴 [AUTH_REPO] Unexpected error: $e');
      return AuthResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Login with username and password
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      print('🔵 [AUTH_REPO] Attempting login for: $username');

      final request = LoginRequestDto(
        username: username,
        password: password,
      );

      final response = await _apiClient.login(request);

      print('✅ [AUTH_REPO] Login successful for user: ${response.user.username}');

      return AuthResult.success(
        user: User(
          userId: response.user.userId,
          username: response.user.username,
          email: response.user.email,
          passwordHash: '',
          createdAt: DateTime.now(),
        ),
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        message: 'Login successful',
      );
    } on DioException catch (e) {
      return _handleDioException(e, 'Login failed');
    } catch (e) {
      print('🔴 [AUTH_REPO] Unexpected error: $e');
      return AuthResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Handle Dio exceptions and return appropriate error messages
  AuthResult _handleDioException(DioException e, String defaultMessage) {
    print('🔴 [AUTH_REPO] DioException:');
    print('  - Type: ${e.type}');
    print('  - Status Code: ${e.response?.statusCode}');
    print('  - Response Data: ${e.response?.data}');

    String errorMessage = defaultMessage;

    if (e.response?.statusCode == 400) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] != null) {
        errorMessage = responseData['message'];
      } else {
        errorMessage = 'Invalid request data';
      }
    } else if (e.response?.statusCode == 401) {
      errorMessage = 'Invalid username or password';
    } else if (e.response?.statusCode == 404) {
      errorMessage = 'Account not found';
    } else if (e.response?.statusCode == 409) {
      errorMessage = 'An account with this email already exists';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Connection timeout. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'Could not connect to server';
    }

    print('❌ [AUTH_REPO] Error: $errorMessage');
    return AuthResult.failure(message: errorMessage);
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final String message;
  final User? user;
  final String? accessToken;
  final String? refreshToken;

  const AuthResult._({
    required this.success,
    required this.message,
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthResult.success({
    required User user,
    required String accessToken,
    required String refreshToken,
    String message = 'Success',
  }) {
    return AuthResult._(
      success: true,
      message: message,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  factory AuthResult.failure({
    required String message,
  }) {
    return AuthResult._(
      success: false,
      message: message,
    );
  }
}
