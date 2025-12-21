import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/survey_response_dto.dart';

/// API client for survey response endpoints
class SurveyApiClient {
  final Dio _dio;

  SurveyApiClient({required String baseUrl, Dio? dio})
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

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Get my survey responses
  /// GET /api/v1/survey-responses/my
  Future<List<SurveyResponseDto>> getMySurveyResponses({
    String? accessToken,
  }) async {
    final response = await _dio.get(
      '/api/v1/survey-responses/my',
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    final data = _decodeResponse(response.data);

    // Handle both list and single object responses
    if (data is List) {
      return data
          .map((e) => SurveyResponseDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (data is Map<String, dynamic>) {
      // If it's a paginated response
      if (data.containsKey('content')) {
        return (data['content'] as List)
            .map((e) => SurveyResponseDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      // If it's a single object
      return [SurveyResponseDto.fromJson(data)];
    }

    return [];
  }

  /// Create a new survey response
  /// POST /api/v1/survey-responses
  Future<SurveyResponseDto> createSurveyResponse(
    SurveyResponseDto request, {
    String? accessToken,
  }) async {
    final requestBody = request.toJson();
    final response = await _dio.post(
      '/api/v1/survey-responses',
      data: requestBody,
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );
    return SurveyResponseDto.fromJson(_decodeResponse(response.data));
  }

  /// Update an existing survey response
  /// PUT /api/v1/survey-responses/{id}
  Future<SurveyResponseDto> updateSurveyResponse(
    int id,
    SurveyResponseDto request, {
    String? accessToken,
  }) async {
    final response = await _dio.put(
      '/api/v1/survey-responses/$id',
      data: request.toJson(),
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    return SurveyResponseDto.fromJson(_decodeResponse(response.data));
  }

  /// Delete a survey response
  /// DELETE /api/v1/survey-responses/{id}
  Future<void> deleteSurveyResponse(int id, {String? accessToken}) async {
    await _dio.delete(
      '/api/v1/survey-responses/$id',
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is List) return data;
    if (data is String) {
      final decoded = json.decode(data);
      return decoded;
    }
    throw const FormatException('Unexpected response format');
  }
}
