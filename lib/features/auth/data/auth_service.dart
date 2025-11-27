// Authentication service using the new repository layer
import '../../../core/models/user.dart';
import 'auth_repository.dart';

class AuthService {
  final AuthRepository _repository;

  static String? _accessToken;
  static String? _refreshToken;
  static User? _currentUser;

  AuthService({
    String baseUrl = 'http://35.158.35.102:8080',
    AuthRepository? repository,
  }) : _repository = repository ?? AuthRepository(baseUrl: baseUrl);

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
    }

    return result;
  }

  // Sign up using the repository
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

    if (result.success && result.user != null) {
      _accessToken = result.accessToken;
      _refreshToken = result.refreshToken;
      _currentUser = result.user;
    }

    return result;
  }

  // Mock Google sign in (to be implemented later)
  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    return AuthResult.failure(
      message: 'Google sign in not yet implemented',
    );
  }

  // Mock Apple sign in (to be implemented later)
  Future<AuthResult> signInWithApple() async {
    await Future.delayed(const Duration(seconds: 1));
    return AuthResult.failure(
      message: 'Apple sign in not yet implemented',
    );
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
  }
}
