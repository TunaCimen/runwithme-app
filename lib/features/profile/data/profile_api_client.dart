import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/models/user_profile.dart';

/// API client for user profile endpoints
class ProfileApiClient {
  final Dio _dio;

  ProfileApiClient({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ));

  /// Get user profile by user ID
  Future<UserProfile> getUserProfile(int userId, {String? accessToken}) async {
    final response = await _dio.get(
      '/api/v1/users/$userId/profile',
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );
    return UserProfile.fromJson(_decodeResponse(response.data));
  }

  /// Update user profile
  Future<UserProfile> updateUserProfile(
    int userId,
    UserProfile profile, {
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/v1/users/$userId/profile',
      data: profile.toJson(),
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    return UserProfile.fromJson(_decodeResponse(response.data));
  }

  /// Create user profile
  /// Note: This endpoint DOES not exist on the server. Adjust accordingly.
  Future<UserProfile> createUserProfile(
    UserProfile profile, {
    required String accessToken,
  }) async {
    final response = await _dio.post(
      '/api/v1/users/${profile.userId}/profile',
      data: profile.toJson(),
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    return UserProfile.fromJson(_decodeResponse(response.data));
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture(
    int userId,
    String filePath, {
    required String accessToken,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      '/api/v1/users/$userId/profile/picture',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );

    final data = _decodeResponse(response.data);
    return data['profilePicUrl'] as String;
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw FormatException('Unexpected response format');
  }
}
