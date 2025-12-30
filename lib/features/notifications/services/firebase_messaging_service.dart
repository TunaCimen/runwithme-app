import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/notifications_repository.dart';

/// Service to handle Firebase Cloud Messaging integration
class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging;
  final NotificationsRepository _notificationsRepository;

  String? _currentToken;
  String? _accessToken;

  FirebaseMessagingService({
    FirebaseMessaging? firebaseMessaging,
    NotificationsRepository? notificationsRepository,
  }) : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
       _notificationsRepository =
           notificationsRepository ?? NotificationsRepository();

  /// Get the current FCM token
  String? get currentToken => _currentToken;

  /// Initialize Firebase Messaging and register the device
  /// Call this after user logs in
  Future<bool> initialize({
    required String accessToken,
    String? deviceName,
  }) async {
    _accessToken = accessToken;

    try {
      // Request notification permissions (required for iOS)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          '[FirebaseMessagingService] Notification permission denied',
        );
        return false;
      }

      debugPrint(
        '[FirebaseMessagingService] Permission status: ${settings.authorizationStatus}',
      );

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('[FirebaseMessagingService] Failed to get FCM token');
        return false;
      }

      _currentToken = token;
      debugPrint('[FirebaseMessagingService] FCM Token: $token');

      // Register device with backend
      final result = await _notificationsRepository.registerDevice(
        fcmToken: token,
        accessToken: accessToken,
        deviceName: deviceName,
      );

      if (!result.success) {
        debugPrint(
          '[FirebaseMessagingService] Failed to register device: ${result.message}',
        );
        return false;
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Set up background message opened handler
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      debugPrint('[FirebaseMessagingService] Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[FirebaseMessagingService] Initialization error: $e');
      return false;
    }
  }

  /// Handle token refresh
  /// Firebase may refresh the token periodically
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('[FirebaseMessagingService] Token refreshed: $newToken');

    // Unregister old token if exists
    if (_currentToken != null && _accessToken != null) {
      await _notificationsRepository.unregisterDevice(
        fcmToken: _currentToken!,
        accessToken: _accessToken!,
      );
    }

    _currentToken = newToken;

    // Register new token
    if (_accessToken != null) {
      await _notificationsRepository.registerDevice(
        fcmToken: newToken,
        accessToken: _accessToken!,
      );
    }
  }

  /// Handle foreground messages
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FirebaseMessagingService] Foreground message received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // TODO: Show local notification or handle message in app
    // You might want to use flutter_local_notifications package here
  }

  /// Handle when user taps on a notification
  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FirebaseMessagingService] Message opened app');
    debugPrint('Data: ${message.data}');

    // TODO: Navigate to appropriate screen based on message data
    // Example: Navigate to chat, friend request, or run invitation
  }

  /// Check for initial message (app opened from terminated state via notification)
  Future<RemoteMessage?> getInitialMessage() async {
    return await _firebaseMessaging.getInitialMessage();
  }

  /// Unregister device and cleanup
  /// Call this on logout
  Future<void> cleanup() async {
    if (_currentToken != null && _accessToken != null) {
      await _notificationsRepository.unregisterDevice(
        fcmToken: _currentToken!,
        accessToken: _accessToken!,
      );
    }
    _currentToken = null;
    _accessToken = null;
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('[FirebaseMessagingService] Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('[FirebaseMessagingService] Unsubscribed from topic: $topic');
  }
}

/// Background message handler (must be top-level function)
/// Add this to your main.dart:
/// ```dart
/// @pragma('vm:entry-point')
/// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
///   await Firebase.initializeApp();
///   debugPrint('Background message: ${message.messageId}');
/// }
/// ```
