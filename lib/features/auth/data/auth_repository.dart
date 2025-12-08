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
  /// Returns emailVerificationRequired: true to indicate user needs to verify email
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final request = RegisterRequestDto(
        username: username,
        email: email,
        password: password,
      );

      final response = await _apiClient.register(request);

      return AuthResult.emailVerificationRequired(
        email: response.email,
        message: response.message.isNotEmpty
            ? response.message
            : 'Registration successful! Please check your email to verify your account.',
      );
    } on DioException catch (e) {
      return _handleDioException(e, 'Registration failed');
    } catch (e) {
      return AuthResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Resend verification email
  Future<AuthResult> resendVerificationEmail({required String email}) async {
    try {
      final response = await _apiClient.resendVerificationEmail(email);

      if (response.success) {
        return AuthResult.emailVerificationRequired(
          email: email,
          message: response.message.isNotEmpty
              ? response.message
              : 'Verification email sent! Please check your inbox.',
        );
      } else {
        return AuthResult.failure(
          message: response.message.isNotEmpty
              ? response.message
              : 'Failed to resend verification email',
        );
      }
    } on DioException catch (e) {
      return _handleDioException(e, 'Failed to resend verification email');
    } catch (e) {
      return AuthResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Get user email by username
  Future<String?> getEmailByUsername(String username) async {
    return await _apiClient.getEmailByUsername(username);
  }

  /// Login with username and password
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final request = LoginRequestDto(
        username: username,
        password: password,
      );

      final response = await _apiClient.login(request);

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
      return AuthResult.failure(message: 'An unexpected error occurred');
    }
  }

  /// Handle Dio exceptions and return appropriate error messages
  AuthResult _handleDioException(DioException e, String defaultMessage) {
    String errorMessage = defaultMessage;
    final responseData = e.response?.data;

    if (e.response?.statusCode == 400) {
      if (responseData is Map && responseData['message'] != null) {
        errorMessage = responseData['message'];
      } else {
        errorMessage = 'Invalid request data';
      }
    } else if (e.response?.statusCode == 401) {
      if (responseData is Map && responseData['message'] != null) {
        var msg = responseData['message'].toString().toLowerCase();
        if (msg.contains('email') && (msg.contains('verify') || msg.contains('verified'))) {
          return AuthResult.emailNotVerified(
            message: responseData['message'],
          );
        }
      }
      errorMessage = 'Invalid username or password';
    } else if (e.response?.statusCode == 403) {
      // 403 Forbidden - often used for email not verified
      if (responseData is Map) {
        if (responseData['emailVerified'] == false ||
            (responseData['message'] != null &&
                responseData['message'].toString().toLowerCase().contains('verif'))) {
          return AuthResult.emailNotVerified(
            message: responseData['message'] ?? 'Email not verified. Please check your inbox.',
            email: responseData['email'] as String?,
          );
        }
        if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }
      }
    } else if (e.response?.statusCode == 404) {
      errorMessage = 'Account not found';
    } else if (e.response?.statusCode == 409) {
      if (responseData is Map && responseData['message'] != null) {
        errorMessage = responseData['message'];
      } else {
        errorMessage = 'An account with this username or email already exists';
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Connection timeout. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'Could not connect to server';
    }

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
  final bool emailVerificationRequired;
  final bool emailNotVerified;
  final String? email;

  const AuthResult._({
    required this.success,
    required this.message,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.emailVerificationRequired = false,
    this.emailNotVerified = false,
    this.email,
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

  /// Registration successful, email verification required
  factory AuthResult.emailVerificationRequired({
    required String email,
    required String message,
  }) {
    return AuthResult._(
      success: true,
      message: message,
      emailVerificationRequired: true,
      email: email,
    );
  }

  /// Login failed because email is not verified
  factory AuthResult.emailNotVerified({
    required String message,
    String? email,
  }) {
    return AuthResult._(
      success: false,
      message: message,
      emailNotVerified: true,
      email: email,
    );
  }
}
