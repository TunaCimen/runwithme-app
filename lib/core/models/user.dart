/// Core user model matching the database schema
class User {
  final String userId;
  final String username;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  const User({
    required this.userId,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      username: json['username'] as String,
      email: json['email'] as String,
      passwordHash:
          json['passwordHash'] as String? ??
          json['password_hash'] as String? ??
          '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'User(userId: $userId, username: $username, email: $email)';
  }

  User copyWith({
    String? userId,
    String? username,
    String? email,
    String? passwordHash,
    DateTime? createdAt,
  }) {
    return User(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
