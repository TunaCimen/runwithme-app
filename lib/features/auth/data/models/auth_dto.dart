/// Authentication DTOs for API communication
class LoginRequestDto {
  final String username;
  final String password;

  const LoginRequestDto({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class RegisterRequestDto {
  final String username;
  final String email;
  final String password;

  const RegisterRequestDto({
    required this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
    };
  }
}

class AuthResponseDto {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UserInfoDto user;

  const AuthResponseDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] as Map<String, dynamic>? ?? {};
    return AuthResponseDto(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      user: UserInfoDto.fromJson(userObj),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'user': user.toJson(),
    };
  }
}

class UserInfoDto {
  final String userId;
  final String username;
  final String email;

  const UserInfoDto({
    required this.userId,
    required this.username,
    required this.email,
  });

  factory UserInfoDto.fromJson(Map<String, dynamic> json) {
    return UserInfoDto(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'email': email,
    };
  }
}

class ApiResponseDto<T> {
  final bool success;
  final String? message;
  final T? data;

  const ApiResponseDto({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResponseDto.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponseDto(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: fromJsonT != null && json['data'] != null
          ? fromJsonT(json['data'])
          : null,
    );
  }
}
