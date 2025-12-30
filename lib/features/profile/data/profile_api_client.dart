import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_statistics.dart';
import '../../map/data/models/route_dto.dart';
import '../../../core/models/run_session.dart';
import '../../feed/data/models/feed_post_dto.dart';

/// Paginated response for user profiles
class PaginatedProfilesResponse {
  final List<UserProfile> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedProfilesResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
}

/// API client for user profile endpoints
class ProfileApiClient {
  final Dio _dio;

  ProfileApiClient({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          );

  /// Get all user profiles (paginated)
  /// GET /api/v1/user-profiles
  Future<PaginatedProfilesResponse> getAllProfiles({
    int page = 0,
    int size = 20,
    String? accessToken,
  }) async {
    final response = await _dio.get(
      '/api/v1/user-profiles',
      queryParameters: {'page': page, 'size': size},
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    final content =
        (data['content'] as List<dynamic>?)
            ?.map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PaginatedProfilesResponse(
      content: content,
      page: data['page'] ?? data['number'] ?? 0,
      size: data['size'] ?? size,
      totalElements: data['totalElements'] ?? 0,
      totalPages: data['totalPages'] ?? 0,
      first: data['first'] ?? true,
      last: data['last'] ?? true,
    );
  }

  /// Get user profile by user ID
  /// GET /api/v1/user-profiles/:id
  /// Returns either full UserProfileDto or LimitedUserProfileDto based on visibility
  Future<UserProfile> getUserProfile(
    String userId, {
    String? accessToken,
  }) async {
    final response = await _dio.get(
      '/api/v1/user-profiles/$userId',
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    return UserProfile.fromJson(data);
  }

  /// Update user profile
  /// PUT /api/v1/user-profiles/:id
  Future<UserProfile> updateUserProfile(
    String userId,
    UserProfile profile, {
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/v1/user-profiles/$userId',
      data: profile.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    return UserProfile.fromJson(_decodeResponse(response.data));
  }

  /// Create user profile
  /// POST /api/v1/user-profiles
  Future<UserProfile> createUserProfile(
    UserProfile profile, {
    required String accessToken,
  }) async {
    final response = await _dio.post(
      '/api/v1/user-profiles',
      data: profile.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    return UserProfile.fromJson(_decodeResponse(response.data));
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture(
    String userId,
    String filePath, {
    required String accessToken,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      '/api/v1/users/$userId/profile/picture',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    final data = _decodeResponse(response.data);
    return data['profilePicUrl'] as String;
  }

  /// Get user statistics
  /// GET /api/v1/users/:userId/statistics
  Future<UserStatistics> getUserStatistics(
    String userId, {
    String? accessToken,
    int? days,
  }) async {
    final response = await _dio.get(
      '/api/v1/users/$userId/statistics',
      queryParameters: days != null ? {'days': days} : null,
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    return UserStatistics.fromJson(_decodeResponse(response.data));
  }

  /// Get user's saved routes
  /// GET /api/v1/users/:userId/saved-routes
  Future<List<RouteDto>> getUserRoutes(
    String userId, {
    String? accessToken,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/users/$userId/saved-routes',
      queryParameters: {'page': page, 'size': size},
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    final content = data['content'] as List<dynamic>? ?? [];
    return content
        .map((e) => RouteDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get user's run sessions
  /// GET /api/v1/run-sessions/user/:userId
  Future<List<RunSession>> getUserRunSessions(
    String userId, {
    String? accessToken,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/run-sessions/user/$userId',
      queryParameters: {'page': page, 'size': size},
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    final content = data['content'] as List<dynamic>? ?? [];
    return content
        .map((e) => RunSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get user's feed posts
  /// GET /api/v1/feed-posts/user/:userId
  Future<List<FeedPostDto>> getUserPosts(
    String userId, {
    String? accessToken,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-posts/user/$userId',
      queryParameters: {'page': page, 'size': size},
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    final content = data['content'] as List<dynamic>? ?? [];
    return content
        .map((e) => FeedPostDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw FormatException('Unexpected response format');
  }
}
