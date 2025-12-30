import 'chat_provider.dart';

/// Global singleton instance of ChatProvider
/// This allows the chat state (including unread count) to be shared across the app
class GlobalChatProvider {
  static final GlobalChatProvider _instance = GlobalChatProvider._internal();
  factory GlobalChatProvider() => _instance;
  GlobalChatProvider._internal();

  ChatProvider? _provider;

  /// Get the global ChatProvider instance
  /// Creates one if it doesn't exist
  ChatProvider get provider {
    _provider ??= ChatProvider();
    return _provider!;
  }

  /// Initialize the provider with auth token
  void initialize(String token, {String? userId}) {
    provider.setAuthToken(token, userId: userId);
    if (userId != null) {
      provider.setCurrentUserId(userId);
    }
    // Fetch initial unread count
    provider.fetchUnreadCount();
  }

  /// Clear the provider (for logout)
  void clear() {
    _provider?.clear();
  }

  /// Dispose and reset the provider
  void dispose() {
    _provider?.dispose();
    _provider = null;
  }
}

/// Convenience getter for the global ChatProvider
ChatProvider get globalChatProvider => GlobalChatProvider().provider;
