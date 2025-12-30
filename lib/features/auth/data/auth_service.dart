// Authentication service using the new repository layer
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/user.dart';
import 'auth_repository.dart';

class AuthService {
  final AuthRepository _repository;

  static String? _accessToken;
  static String? _refreshToken;
  static User? _currentUser;
  static bool _isInitialized = false;

  // Storage keys
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUser = 'auth_user';

  AuthService({
    String baseUrl = 'http://35.158.35.102:8080',
    AuthRepository? repository,
  }) : _repository = repository ?? AuthRepository(baseUrl: baseUrl);

  /// Initialize auth state from local storage
  /// Call this when the app starts
  static Future<bool> initializeFromStorage() async {
    if (_isInitialized) return _accessToken != null;

    try {
      final prefs = await SharedPreferences.getInstance();

      _accessToken = prefs.getString(_keyAccessToken);
      _refreshToken = prefs.getString(_keyRefreshToken);

      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userMap);
      }

      _isInitialized = true;
      return _accessToken != null && _currentUser != null;
    } catch (e) {
      _isInitialized = true;
      return false;
    }
  }

  /// Save auth state to local storage
  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_accessToken != null) {
        await prefs.setString(_keyAccessToken, _accessToken!);
      } else {
        await prefs.remove(_keyAccessToken);
      }

      if (_refreshToken != null) {
        await prefs.setString(_keyRefreshToken, _refreshToken!);
      } else {
        await prefs.remove(_keyRefreshToken);
      }

      if (_currentUser != null) {
        await prefs.setString(_keyUser, json.encode(_currentUser!.toJson()));
      } else {
        await prefs.remove(_keyUser);
      }
    } catch (e) {
      // Silently fail - storage is not critical
    }
  }

  /// Clear auth state from local storage
  static Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyUser);
    } catch (e) {
      // Silently fail
    }
  }

  // Login using the repository
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final result = await _repository.login(
      username: username,
      password: password,
    );

    if (result.success && result.user != null) {
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      _currentUser = result.user;

      // Save to local storage for persistent login
      await _saveToStorage();
    }

    return result;
  }

  // Sign up using the repository
  // Note: After registration, user needs to verify their email before logging in
  // Profile creation is now handled after the user verifies email and logs in
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    final result = await _repository.register(
      username: username,
      email: email,
      password: password,
    );

    // Registration now returns emailVerificationRequired,
    // no tokens are provided until email is verified
    return result;
  }

  // Resend verification email
  Future<AuthResult> resendVerificationEmail({required String email}) async {
    return await _repository.resendVerificationEmail(email: email);
  }

  // Get user email by username (for resend verification flow)
  Future<String?> getEmailByUsername(String username) async {
    return await _repository.getEmailByUsername(username);
  }

  // Mock Google sign in (to be implemented later)
  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    return AuthResult.failure(message: 'Google sign in not yet implemented');
  }

  // Mock Apple sign in (to be implemented later)
  Future<AuthResult> signInWithApple() async {
    await Future.delayed(const Duration(seconds: 1));
    return AuthResult.failure(message: 'Apple sign in not yet implemented');
  }

  // Check if user is logged in
  bool get isLoggedIn => _accessToken != null && _currentUser != null;

  // Get current user
  User? get currentUser => _currentUser;

  // Get access token
  String? get accessToken => _accessToken;

  // Get refresh token
  String? get refreshToken => _refreshToken;

  // Logout
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    // Clear from local storage
    await _clearStorage();
  }
}
