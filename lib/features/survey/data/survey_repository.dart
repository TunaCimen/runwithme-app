import 'package:dio/dio.dart';
import 'survey_api_client.dart';
import 'models/survey_response_dto.dart';

/// Result wrapper for survey operations
class SurveyResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  SurveyResult._({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory SurveyResult.success(T data, {String? message}) {
    return SurveyResult._(success: true, data: data, message: message);
  }

  factory SurveyResult.failure({String? message, String? errorCode}) {
    return SurveyResult._(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Repository for survey response operations
class SurveyRepository {
  // Singleton instance
  static SurveyRepository? _instance;

  final SurveyApiClient _apiClient;

  // Cache for current user's survey response
  SurveyResponseDto? _cachedResponse;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Private constructor for singleton
  SurveyRepository._internal({
    String baseUrl = 'http://35.158.35.102:8080',
    SurveyApiClient? apiClient,
  }) : _apiClient = apiClient ?? SurveyApiClient(baseUrl: baseUrl);

  /// Factory constructor that returns singleton
  factory SurveyRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    SurveyApiClient? apiClient,
  }) {
    _instance ??= SurveyRepository._internal(
      baseUrl: baseUrl,
      apiClient: apiClient,
    );
    return _instance!;
  }

  /// Get singleton instance
  static SurveyRepository get instance {
    _instance ??= SurveyRepository._internal();
    return _instance!;
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  /// Clear cache
  void clearCache() {
    _cachedResponse = null;
    _cacheTimestamp = null;
  }

  /// Get cached response (if available)
  SurveyResponseDto? get cachedResponse => _cachedResponse;

  /// Check if user has completed survey (from cache)
  bool get hasCompletedSurvey => _cachedResponse != null;

  /// Get my survey response
  Future<SurveyResult<SurveyResponseDto?>> getMySurveyResponse({
    required String accessToken,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid
    if (!forceRefresh && _isCacheValid() && _cachedResponse != null) {
      return SurveyResult.success(_cachedResponse);
    }

    try {
      final responses = await _apiClient.getMySurveyResponses(
        accessToken: accessToken,
      );

      if (responses.isNotEmpty) {
        // Take the most recent response
        _cachedResponse = responses.first;
        _cacheTimestamp = DateTime.now();
        return SurveyResult.success(_cachedResponse);
      }

      // No survey response exists
      _cachedResponse = null;
      _cacheTimestamp = DateTime.now();
      return SurveyResult.success(null, message: 'No survey response found');
    } on DioException catch (e) {
      // 404 means no survey exists yet - that's okay
      if (e.response?.statusCode == 404) {
        _cachedResponse = null;
        _cacheTimestamp = DateTime.now();
        return SurveyResult.success(null, message: 'No survey response found');
      }
      return _handleDioError(e);
    } catch (e) {
      return SurveyResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Create a new survey response
  Future<SurveyResult<SurveyResponseDto>> createSurveyResponse(
    SurveyResponseDto request, {
    required String accessToken,
  }) async {
    try {
      final response = await _apiClient.createSurveyResponse(
        request,
        accessToken: accessToken,
      );

      // Update cache
      _cachedResponse = response;
      _cacheTimestamp = DateTime.now();

      return SurveyResult.success(
        response,
        message: 'Survey saved successfully',
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return SurveyResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Update an existing survey response
  Future<SurveyResult<SurveyResponseDto>> updateSurveyResponse(
    int id,
    SurveyResponseDto request, {
    required String accessToken,
  }) async {
    try {
      final response = await _apiClient.updateSurveyResponse(
        id,
        request,
        accessToken: accessToken,
      );

      // Update cache
      _cachedResponse = response;
      _cacheTimestamp = DateTime.now();

      return SurveyResult.success(
        response,
        message: 'Survey updated successfully',
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return SurveyResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Save survey response (creates new or updates existing)
  Future<SurveyResult<SurveyResponseDto>> saveSurveyResponse(
    SurveyResponseDto request, {
    required String accessToken,
  }) async {
    if (_cachedResponse?.id != null) {
      return updateSurveyResponse(
        _cachedResponse!.id!,
        request,
        accessToken: accessToken,
      );
    } else {
      return createSurveyResponse(request, accessToken: accessToken);
    }
  }

  /// Delete a survey response
  Future<SurveyResult<void>> deleteSurveyResponse(
    int id, {
    required String accessToken,
  }) async {
    try {
      await _apiClient.deleteSurveyResponse(id, accessToken: accessToken);

      // Clear cache
      _cachedResponse = null;
      _cacheTimestamp = null;

      return SurveyResult.success(null, message: 'Survey deleted successfully');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return SurveyResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  SurveyResult<T> _handleDioError<T>(DioException e) {
    String message;
    String? errorCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please try again.';
        errorCode = 'TIMEOUT';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (statusCode == 401) {
          message = 'Session expired. Please log in again.';
          errorCode = 'UNAUTHORIZED';
        } else if (statusCode == 403) {
          message = 'You do not have permission to perform this action.';
          errorCode = 'FORBIDDEN';
        } else if (statusCode == 404) {
          message = 'Survey not found.';
          errorCode = 'NOT_FOUND';
        } else if (statusCode == 409) {
          message = 'Survey response already exists.';
          errorCode = 'CONFLICT';
        } else {
          message = responseData?['message'] ?? 'An error occurred.';
          errorCode = 'SERVER_ERROR';
        }
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        errorCode = 'NO_CONNECTION';
        break;
      default:
        message = e.message ?? 'An unexpected error occurred.';
        errorCode = 'UNKNOWN';
    }

    return SurveyResult.failure(message: message, errorCode: errorCode);
  }
}
