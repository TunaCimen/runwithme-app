import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'recommendations_api_client.dart';
import 'models/recommendation_dto.dart';

/// Repository for user recommendations
class RecommendationsRepository {
  final RecommendationsApiClient _apiClient;

  // Cache
  PaginatedRecommendations? _cachedRecommendations;
  DateTime? _cacheTimestamp;
  static const _cacheTimeout = Duration(minutes: 5);

  RecommendationsRepository({String baseUrl = 'http://35.158.35.102:8080'})
    : _apiClient = RecommendationsApiClient(baseUrl: baseUrl);

  /// Set authentication token
  void setAuthToken(String token) {
    _apiClient.setAuthToken(token);
  }

  /// Clear cache
  void clearCache() {
    _cachedRecommendations = null;
    _cacheTimestamp = null;
  }

  /// Check if cache is valid
  bool get _isCacheValid {
    if (_cachedRecommendations == null || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheTimeout;
  }

  /// Get recommended users
  Future<RecommendationsResult> getRecommendations({
    required String accessToken,
    int page = 0,
    int size = 20,
    LocationLevel locationLevel = LocationLevel.city,
    bool forceRefresh = false,
  }) async {
    debugPrint(
      '[RecommendationsRepository] Getting recommendations: page=$page, forceRefresh=$forceRefresh',
    );

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && page == 0 && _isCacheValid) {
      debugPrint(
        '[RecommendationsRepository] Returning cached recommendations',
      );
      return RecommendationsResult.success(
        recommendations: _cachedRecommendations!.content,
        hasMore: !_cachedRecommendations!.last,
        totalElements: _cachedRecommendations!.totalElements,
      );
    }

    try {
      final response = await _apiClient.getRecommendedUsers(
        page: page,
        size: size,
        locationLevel: locationLevel,
        accessToken: accessToken,
      );

      // Cache first page
      if (page == 0) {
        _cachedRecommendations = response;
        _cacheTimestamp = DateTime.now();
      }

      debugPrint(
        '[RecommendationsRepository] Got ${response.content.length} recommendations',
      );

      return RecommendationsResult.success(
        recommendations: response.content,
        hasMore: !response.last,
        totalElements: response.totalElements,
      );
    } on DioException catch (e) {
      debugPrint('[RecommendationsRepository] DioException: ${e.type}');
      debugPrint('[RecommendationsRepository] Error message: ${e.message}');
      debugPrint('[RecommendationsRepository] Response status: ${e.response?.statusCode}');
      debugPrint('[RecommendationsRepository] Response data: ${e.response?.data}');
      return _handleDioException(e);
    } catch (e, stackTrace) {
      debugPrint('[RecommendationsRepository] Unexpected error: $e');
      debugPrint('[RecommendationsRepository] Stack trace: $stackTrace');
      return RecommendationsResult.failure(
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Get similarity with a specific user
  Future<SimilarityResult> getSimilarityWithUser(
    String targetUserId, {
    required String accessToken,
  }) async {
    try {
      final result = await _apiClient.getSimilarityWithUser(
        targetUserId,
        accessToken: accessToken,
      );

      return SimilarityResult.success(recommendation: result);
    } on DioException catch (e) {
      debugPrint('[RecommendationsRepository] Error: ${e.message}');
      final result = _handleDioException(e);
      return SimilarityResult.failure(message: result.message);
    } catch (e) {
      return SimilarityResult.failure(message: 'An unexpected error occurred');
    }
  }

  RecommendationsResult _handleDioException(DioException e) {
    String errorMessage = 'Failed to load recommendations';

    if (e.response?.statusCode == 401) {
      errorMessage = 'Please log in to see recommendations';
    } else if (e.response?.statusCode == 404) {
      // No recommendations found is not an error
      return RecommendationsResult.success(
        recommendations: [],
        hasMore: false,
        totalElements: 0,
      );
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Connection timed out. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'No internet connection';
    }

    return RecommendationsResult.failure(message: errorMessage);
  }
}

/// Result wrapper for recommendations
class RecommendationsResult {
  final bool success;
  final String message;
  final List<RecommendationDto> recommendations;
  final bool hasMore;
  final int totalElements;

  const RecommendationsResult._({
    required this.success,
    required this.message,
    this.recommendations = const [],
    this.hasMore = false,
    this.totalElements = 0,
  });

  factory RecommendationsResult.success({
    required List<RecommendationDto> recommendations,
    required bool hasMore,
    required int totalElements,
    String message = 'Success',
  }) {
    return RecommendationsResult._(
      success: true,
      message: message,
      recommendations: recommendations,
      hasMore: hasMore,
      totalElements: totalElements,
    );
  }

  factory RecommendationsResult.failure({required String message}) {
    return RecommendationsResult._(success: false, message: message);
  }
}

/// Result wrapper for similarity check
class SimilarityResult {
  final bool success;
  final String message;
  final RecommendationDto? recommendation;

  const SimilarityResult._({
    required this.success,
    required this.message,
    this.recommendation,
  });

  factory SimilarityResult.success({
    required RecommendationDto recommendation,
    String message = 'Success',
  }) {
    return SimilarityResult._(
      success: true,
      message: message,
      recommendation: recommendation,
    );
  }

  factory SimilarityResult.failure({required String message}) {
    return SimilarityResult._(success: false, message: message);
  }
}
