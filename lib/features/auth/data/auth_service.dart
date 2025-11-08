// Mock authentication service
// Will be replaced with real API calls to Spring Boot backend with JWT

class AuthService {
  // Simulated user storage (in-memory for now)
  static final Map<String, Map<String, String>> _mockUsers = {
    "idilissever@gmail.com": {
      "username": "idilissever",
      "fullName": "Idil Issever",
      "password": "password123",
    },
    "john.doe@test.com": {
      "username": "johndoe",
      "fullName": "John Doe",
      "password": "run123",
    },
    "sarah.runner@test.com": {
      "username": "sarahrunner",
      "fullName": "Sarah Runner",
      "password": "runner456",
    },
  };
  static String? _currentUserEmail;

  // Mock login - validates credentials
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Check if user exists
    if (!_mockUsers.containsKey(email)) {
      return AuthResult(
        success: false,
        message: 'No account found with this email',
      );
    }

    // Validate password
    if (_mockUsers[email]!['password'] != password) {
      return AuthResult(
        success: false,
        message: 'Incorrect password',
      );
    }

    _currentUserEmail = email;
    return AuthResult(
      success: true,
      message: 'Login successful',
      user: UserData(
        email: email,
        username: _mockUsers[email]!['username']!,
        fullName: _mockUsers[email]!['fullName']!,
      ),
    );
  }

  // Mock sign up - creates new user
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Check if email already exists
    if (_mockUsers.containsKey(email)) {
      return AuthResult(
        success: false,
        message: 'An account with this email already exists',
      );
    }

    // Check if username is taken
    var usernameTaken = _mockUsers.values.any(
      (user) => user['username'] == username,
    );
    if (usernameTaken) {
      return AuthResult(
        success: false,
        message: 'Username is already taken',
      );
    }

    // Create new user
    _mockUsers[email] = {
      'password': password,
      'username': username,
      'fullName': fullName,
    };

    _currentUserEmail = email;
    return AuthResult(
      success: true,
      message: 'Account created successfully',
      user: UserData(
        email: email,
        username: username,
        fullName: fullName,
      ),
    );
  }

  // Mock Google sign in
  Future<AuthResult> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    // Placeholder - will integrate with google_sign_in package later
    return AuthResult(
      success: false,
      message: 'Google sign in not yet implemented',
    );
  }

  // Mock Apple sign in
  Future<AuthResult> signInWithApple() async {
    await Future.delayed(const Duration(seconds: 1));
    // Placeholder - will integrate with sign_in_with_apple package later
    return AuthResult(
      success: false,
      message: 'Apple sign in not yet implemented',
    );
  }

  // Check if user is logged in
  bool get isLoggedIn => _currentUserEmail != null;

  // Get current user
  UserData? get currentUser {
    if (_currentUserEmail == null) return null;
    var userData = _mockUsers[_currentUserEmail];
    if (userData == null) return null;

    return UserData(
      email: _currentUserEmail!,
      username: userData['username']!,
      fullName: userData['fullName']!,
    );
  }

  // Logout
  Future<void> logout() async {
    _currentUserEmail = null;
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
  final String email;
  final String username;
  final String fullName;

  UserData({
    required this.email,
    required this.username,
    required this.fullName,
  });
}
