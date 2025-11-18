// Real authentication service using Spring Boot backend with JWT
import '../../../user.dart';
import 'package:dio/dio.dart';

class AuthService {
  final UserApiClient _apiClient = UserApiClient(
    baseUrl: 'http://35.158.35.102:8080',
  );

  static String? _accessToken;
  static String? _refreshToken;
  static UserData? _currentUser;

  // Real login - calls backend API
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      print('🔵 [AUTH] Attempting login for: $username');
      print('🔵 [AUTH] API URL: http://35.158.35.102:8080/api/v1/auth/login');
      
      final response = await _apiClient.loginUser(
        username: username,
        password: password,
      );

      print('🟢 [AUTH] Login response received:');
      print('  - Success: ${response.success}');
      print('  - Message: ${response.message}');
      print('  - User: ${response.user?.email}');
      if (response.user?.accessToken != null) {
        final token = response.user!.accessToken;
        print('  - Access Token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      }

      if (response.success && response.user != null) {
        _accessToken = response.user!.accessToken;
        _refreshToken = response.user!.refreshToken;
        _currentUser = UserData(
          userId: response.user!.userId,
          email: response.user!.email,
          username: response.user!.userName,
          fullName: response.user!.userName, // Backend doesn't return fullName yet
        );

        print('✅ [AUTH] Login successful for user: ${_currentUser!.username}');
        return AuthResult(
          success: true,
          message: 'Login successful',
          user: _currentUser,
        );
      } else {
        print('❌ [AUTH] Login failed: ${response.message}');
        return AuthResult(
          success: false,
          message: response.message ?? 'Login failed',
        );
      }
    } on DioException catch (e) {
      print('🔴 [AUTH] DioException caught:');
      print('  - Type: ${e.type}');
      print('  - Status Code: ${e.response?.statusCode}');
      print('  - Response Data: ${e.response?.data}');
      print('  - Error Message: ${e.message}');
      
      String errorMessage = 'Login failed';
      
      if (e.response?.statusCode == 401) {
        errorMessage = 'Invalid username or password';
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'No account found with this username';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Could not connect to server';
      }

      print('❌ [AUTH] Login error: $errorMessage');
      return AuthResult(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      print('🔴 [AUTH] Unexpected error: $e');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  // Real sign up - calls backend API
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    try {
      print('🔵 [AUTH] Attempting registration for: $email');
      print('🔵 [AUTH] Username: $username');
      print('🔵 [AUTH] API URL: http://35.158.35.102:8080/api/v1/auth/register');
      
      final response = await _apiClient.registerUser(
        username: username,
        email: email,
        password: password,
      );

      print('🟢 [AUTH] Registration response received:');
      print('  - Success: ${response.success}');
      print('  - Message: ${response.message}');
      print('  - User: ${response.user?.email}');
      print('  - User ID: ${response.user?.userId}');

      if (response.success && response.user != null) {
        _accessToken = response.user!.accessToken;
        _refreshToken = response.user!.refreshToken;
        _currentUser = UserData(
          userId: response.user!.userId,
          email: response.user!.email,
          username: response.user!.userName,
          fullName: fullName ?? response.user!.userName,
        );

        print('✅ [AUTH] Registration successful for user: ${_currentUser!.username}');
        return AuthResult(
          success: true,
          message: 'Account created successfully',
          user: _currentUser,
        );
      } else {
        print('❌ [AUTH] Registration failed: ${response.message}');
        return AuthResult(
          success: false,
          message: response.message ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      print('🔴 [AUTH] DioException caught during registration:');
      print('  - Type: ${e.type}');
      print('  - Status Code: ${e.response?.statusCode}');
      print('  - Response Data: ${e.response?.data}');
      print('  - Error Message: ${e.message}');
      
      String errorMessage = 'Registration failed';
      
      if (e.response?.statusCode == 400) {
        final responseData = e.response?.data;
        if (responseData is Map && responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else {
          errorMessage = 'Invalid registration data';
        }
      } else if (e.response?.statusCode == 409) {
        errorMessage = 'An account with this email already exists';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Could not connect to server';
      }

      print('❌ [AUTH] Registration error: $errorMessage');
      return AuthResult(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      print('🔴 [AUTH] Unexpected registration error: $e');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  // Mock Google sign in (to be implemented later)
  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    return AuthResult(
      success: false,
      message: 'Google sign in not yet implemented',
    );
  }

  // Mock Apple sign in (to be implemented later)
  Future<AuthResult> signInWithApple() async {
    await Future.delayed(const Duration(seconds: 1));
    return AuthResult(
      success: false,
      message: 'Apple sign in not yet implemented',
    );
  }

  // Check if user is logged in
  bool get isLoggedIn => _accessToken != null && _currentUser != null;

  // Get current user
  UserData? get currentUser => _currentUser;

  // Get access token
  String? get accessToken => _accessToken;

  // Logout
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
  }
}

// Authentication result
class AuthResult {
  final bool success;
  final String message;
  final UserData? user;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}

// User data model
class UserData {
  final int userId;
  final String email;
  final String username;
  final String fullName;

  UserData({
    required this.userId,
    required this.email,
    required this.username,
    required this.fullName,
  });
}
