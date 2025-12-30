import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'models/recommendation_dto.dart';

/// API client for user recommendations
class RecommendationsApiClient {
  final Dio _dio;

  RecommendationsApiClient({String baseUrl = 'http://35.158.35.102:8080'})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      );

  /// Set authentication token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Get recommended users
  /// GET /api/v1/recommendations/users
  Future<PaginatedRecommendations> getRecommendedUsers({
    int page = 0,
    int size = 10,
    LocationLevel locationLevel = LocationLevel.city,
    String? accessToken,
  }) async {
    debugPrint(
      '[RecommendationsApiClient] Fetching recommendations: page=$page, size=$size, locationLevel=${locationLevel.toApiString()}',
    );

    final response = await _dio.get(
      '/api/v1/recommendations/users',
      queryParameters: {
        'page': page,
        'size': size,
        'locationLevel': locationLevel.toApiString(),
      },
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    debugPrint('[RecommendationsApiClient] Response: $data');

    return PaginatedRecommendations.fromJson(data);
  }

  /// Get similarity score with a specific user
  /// GET /api/v1/recommendations/users/{targetUserId}/similarity
  Future<RecommendationDto> getSimilarityWithUser(
    String targetUserId, {
    String? accessToken,
  }) async {
    debugPrint(
      '[RecommendationsApiClient] Fetching similarity with user: $targetUserId',
    );

    final response = await _dio.get(
      '/api/v1/recommendations/users/$targetUserId/similarity',
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);
    debugPrint('[RecommendationsApiClient] Similarity response: $data');

    return RecommendationDto.fromJson(data);
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw const FormatException('Unexpected response format');
  }
}
