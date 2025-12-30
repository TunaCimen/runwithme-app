import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/device_registration_dto.dart';

/// API client for notification endpoints
class NotificationsApiClient {
  final Dio _dio;

  NotificationsApiClient({required String baseUrl, Dio? dio})
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

  /// Register a device for push notifications
  /// POST /api/v1/notifications/devices
  Future<DeviceRegistrationResponseDto> registerDevice(
    DeviceRegistrationRequestDto request, {
    String? accessToken,
  }) async {
    final response = await _dio.post(
      '/api/v1/notifications/devices',
      data: request.toJson(),
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );

    return DeviceRegistrationResponseDto.fromJson(
      _decodeResponse(response.data),
    );
  }

  /// Unregister a device from push notifications
  /// DELETE /api/v1/notifications/devices/:token
  Future<void> unregisterDevice(
    String fcmToken, {
    String? accessToken,
  }) async {
    await _dio.delete(
      '/api/v1/notifications/devices/$fcmToken',
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
    );
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw const FormatException('Unexpected response format');
  }
}
