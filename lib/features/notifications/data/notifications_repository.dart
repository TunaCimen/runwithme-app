import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'notifications_api_client.dart';
import 'models/device_registration_dto.dart';

/// Result class for notification operations
class NotificationResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  NotificationResult._({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory NotificationResult.success(T data, {String? message}) {
    return NotificationResult._(success: true, data: data, message: message);
  }

  factory NotificationResult.failure({String? message, String? errorCode}) {
    return NotificationResult._(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Repository for notification-related operations
class NotificationsRepository {
  final NotificationsApiClient _apiClient;

  NotificationsRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    NotificationsApiClient? apiClient,
  }) : _apiClient = apiClient ?? NotificationsApiClient(baseUrl: baseUrl);

  /// Set authorization token
  void setAuthToken(String token) {
    _apiClient.setAuthToken(token);
  }

  /// Register device for push notifications
  /// Call this after getting the FCM token from Firebase Messaging
  Future<NotificationResult<DeviceRegistrationResponseDto>> registerDevice({
    required String fcmToken,
    required String accessToken,
    String? deviceName,
  }) async {
    try {
      final platform = _getCurrentPlatform();

      final request = DeviceRegistrationRequestDto(
        token: fcmToken,
        platform: platform,
        deviceName: deviceName ?? _getDefaultDeviceName(),
      );

      final result = await _apiClient.registerDevice(
        request,
        accessToken: accessToken,
      );

      debugPrint('[NotificationsRepository] Device registered successfully');
      return NotificationResult.success(
        result,
        message: 'Device registered for notifications',
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      debugPrint('[NotificationsRepository] Registration error: $e');
      return NotificationResult.failure(message: e.toString());
    }
  }

  /// Unregister device from push notifications
  /// Call this on logout or when user disables notifications
  Future<NotificationResult<void>> unregisterDevice({
    required String fcmToken,
    required String accessToken,
  }) async {
    try {
      await _apiClient.unregisterDevice(fcmToken, accessToken: accessToken);
      debugPrint('[NotificationsRepository] Device unregistered successfully');
      return NotificationResult.success(
        null,
        message: 'Device unregistered from notifications',
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      debugPrint('[NotificationsRepository] Unregister error: $e');
      return NotificationResult.failure(message: e.toString());
    }
  }

  /// Get the current platform
  DevicePlatform _getCurrentPlatform() {
    if (kIsWeb) {
      return DevicePlatform.web;
    }
    if (Platform.isAndroid) {
      return DevicePlatform.android;
    }
    if (Platform.isIOS) {
      return DevicePlatform.ios;
    }
    // Default to Android for other platforms
    return DevicePlatform.android;
  }

  /// Get default device name based on platform
  String _getDefaultDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    }
    if (Platform.isAndroid) {
      return 'Android Device';
    }
    if (Platform.isIOS) {
      return 'iOS Device';
    }
    return 'Unknown Device';
  }

  /// Handle Dio exceptions
  NotificationResult<T> _handleDioError<T>(DioException e) {
    debugPrint('[NotificationsRepository] DioException: ${e.message}');
    debugPrint('[NotificationsRepository] Response: ${e.response?.data}');

    String errorMessage = 'Network error occurred';
    String? errorCode;

    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        errorMessage = data['message'] as String? ??
            data['error'] as String? ??
            errorMessage;
        errorCode = data['errorCode'] as String?;
      }

      switch (e.response!.statusCode) {
        case 400:
          errorMessage = 'Invalid device registration data';
          break;
        case 401:
          errorMessage = 'Authentication required';
          errorCode = 'UNAUTHORIZED';
          break;
        case 403:
          errorMessage = 'Access denied';
          errorCode = 'FORBIDDEN';
          break;
        case 409:
          errorMessage = 'Device already registered';
          errorCode = 'ALREADY_REGISTERED';
          break;
        case 500:
          errorMessage = 'Server error occurred';
          break;
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorMessage = 'Connection timeout. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'No internet connection';
    }

    return NotificationResult.failure(
      message: errorMessage,
      errorCode: errorCode,
    );
  }
}
