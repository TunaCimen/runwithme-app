// Authentication service using the new repository layer
import '../../../core/models/user.dart';
import '../../../core/models/user_profile.dart';
import 'auth_repository.dart';
import '../../profile/data/profile_repository.dart';

class AuthService {
  final AuthRepository _repository;
  final ProfileRepository _profileRepository;

  static String? _accessToken;
  static String? _refreshToken;
  static User? _currentUser;

  AuthService({
    String baseUrl = 'http://35.158.35.102:8080',
    AuthRepository? repository,
    ProfileRepository? profileRepository,
  }) : _repository = repository ?? AuthRepository(baseUrl: baseUrl),
       _profileRepository = profileRepository ?? ProfileRepository();

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

      // Automatically create user profile with initial data
      if (fullName != null && fullName.isNotEmpty && _accessToken != null) {
        try {
          // Split full name into first and last name
          final nameParts = fullName.trim().split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts.first : '';
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

          final profile = UserProfile(
            userId: result.user!.userId,
            firstName: firstName.isNotEmpty ? firstName : null,
            lastName: lastName.isNotEmpty ? lastName : null,
          );

          await _profileRepository.createProfile(
            profile,
            accessToken: _accessToken!,
          );
        } catch (e) {
          // If profile creation fails, log but don't fail the registration
          print('⚠️ [AUTH_SERVICE] Failed to create profile: $e');
        }
      }
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
