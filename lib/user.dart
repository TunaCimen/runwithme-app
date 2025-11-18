import 'dart:convert';
import 'package:dio/dio.dart';

class UserApiClient {

  final Dio _dio;

  UserApiClient({
    required baseUrl,
    Dio? dio,
  }) : _dio = dio ?? 
            Dio(BaseOptions(
              baseUrl:'http://35.158.35.102:8080',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ));

  Future<ResponseUser> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/api/v1/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
    print('DEBUG - Raw response: ${res.data}'); // Debug line
    return ResponseUser.fromJson(_decodeResponse(res.data));
  }

  Future<ResponseUser> loginUser({
    required String username,
    required String password,
  }) async {
    print('📤 [API] Sending login request:');
    print('  - Username: $username');
    print('  - Password: ${password.replaceAll(RegExp(r'.'), '*')}');
    
    final res = await _dio.post(
      '/api/v1/auth/login',
      data: {
        'username': username,
        'password': password,
      },
    );
    
    print('📥 [API] Login response received:');
    print('  - Status Code: ${res.statusCode}');
    print('  - Raw response: ${res.data}');
    
    return ResponseUser.fromJson(_decodeResponse(res.data));
  }

  dynamic _decodeResponse(dynamic data){
    if(data is Map<String, dynamic>) return data;
    if(data is String) return json.decode(data) as Map<String,dynamic>;
    throw FormatException("Format not correct!");
  }
  
}


class UserDto{
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int userId;
  final String userName;
  final String email;

  const UserDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.userId,
    required this.userName,
    required this.email,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] as Map<String, dynamic>? ?? {};
    return UserDto(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? '',
      userId: (userObj['userId'] as num?)?.toInt() ?? 0,
      userName: userObj['username'] as String? ?? '',
      email: userObj['email'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'UserDto(userId: $userId, userName: $userName, email: $email, tokenType: $tokenType)';
  }
}

class ResponseUser{
  final UserDto? user;
  final String? message;
  final bool success;

  ResponseUser({
    this.user,
    this.message,
    this.success = false,
  });

  factory ResponseUser.fromJson(Map<String,dynamic> json){
    return ResponseUser(
      user: json.containsKey('accessToken') ? UserDto.fromJson(json) : null,
      message: json['message'] as String?,
      success: json.containsKey('accessToken') || (json['success'] as bool? ?? false),
    );
  }

  @override
  String toString() {
    return 'ResponseUser(success: $success, message: $message, user: ${user != null ? 'UserDto(...)' : 'null'})';
  }
}

