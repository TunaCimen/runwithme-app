import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';
import '../data/models/message_dto.dart';
import '../data/models/conversation_dto.dart';

/// Provider for managing chat state
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;

  // Conversations list state
  List<ConversationDto> _conversations = [];
  bool _conversationsLoading = false;
  String? _conversationsError;

  // Current conversation state
  String? _activeConversationUserId;
  List<MessageDto> _currentMessages = [];
  bool _messagesLoading = false;
  bool _messagesHasMore = true;
  int _messagesPage = 0;
  String? _messagesError;

  // Action states
  bool _sendingMessage = false;

  // Total unread count
  int _totalUnreadCount = 0;

  ChatProvider({
    String baseUrl = 'http://35.158.35.102:8080',
    ChatRepository? repository,
  }) : _repository = repository ?? ChatRepository(baseUrl: baseUrl);

  // Getters
  List<ConversationDto> get conversations => _conversations;
  bool get conversationsLoading => _conversationsLoading;
  String? get conversationsError => _conversationsError;

  String? get activeConversationUserId => _activeConversationUserId;
  List<MessageDto> get currentMessages => _currentMessages;
  bool get messagesLoading => _messagesLoading;
  bool get messagesHasMore => _messagesHasMore;
  String? get messagesError => _messagesError;

  bool get sendingMessage => _sendingMessage;
  int get totalUnreadCount => _totalUnreadCount;

  /// Set authentication token
  void setAuthToken(String token) {
    _repository.setAuthToken(token);
  }

  /// Load all conversations
  Future<void> loadConversations() async {
    if (_conversationsLoading) return;

    _conversationsLoading = true;
    _conversationsError = null;
    notifyListeners();

    final result = await _repository.getConversations();

    if (result.success && result.data != null) {
      _conversations = result.data!;
      // Sort by last message time (most recent first)
      _conversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      // Calculate total unread count
      _totalUnreadCount = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } else {
      _conversationsError = result.message;
    }

    _conversationsLoading = false;
    notifyListeners();
  }

  /// Open a conversation with a user
  Future<void> openConversation(String userId) async {
    _activeConversationUserId = userId;
    _currentMessages = [];
    _messagesPage = 0;
    _messagesHasMore = true;
    _messagesError = null;

    await loadMessages(refresh: true);

    // Mark conversation as read
    await _repository.markConversationAsRead(userId);
    _updateConversationUnread(userId, 0);
  }

  /// Load messages for the current conversation
  Future<void> loadMessages({bool refresh = false}) async {
    if (_activeConversationUserId == null || _messagesLoading) return;

    if (refresh) {
      _messagesPage = 0;
      _messagesHasMore = true;
    }

    _messagesLoading = true;
    _messagesError = null;
    notifyListeners();

    final result = await _repository.getChatHistory(
      _activeConversationUserId!,
      page: _messagesPage,
    );

    if (result.success && result.data != null) {
      if (refresh) {
        _currentMessages = result.data!.content;
      } else {
        // Append older messages at the end
        _currentMessages = [..._currentMessages, ...result.data!.content];
      }
      _messagesHasMore = !result.data!.last;
      _messagesPage++;
    } else {
      _messagesError = result.message;
    }

    _messagesLoading = false;
    notifyListeners();
  }

  /// Load more messages (pagination - older messages)
  Future<void> loadMoreMessages() async {
    if (!_messagesHasMore || _messagesLoading) return;
    await loadMessages();
  }

  /// Send a message
  Future<ChatResult<MessageDto>> sendMessage(String content) async {
    if (_activeConversationUserId == null) {
      return ChatResult.failure(message: 'No active conversation');
    }

    _sendingMessage = true;
    notifyListeners();

    final result = await _repository.sendMessage(
      recipientId: _activeConversationUserId!,
      content: content,
    );

    if (result.success && result.data != null) {
      // Add message to the beginning of the list (newest first)
      _currentMessages = [result.data!, ..._currentMessages];

      // Update conversation in the list
      _updateConversationWithNewMessage(result.data!);
    }

    _sendingMessage = false;
    notifyListeners();

    return result;
  }

  /// Send a message to a specific user (for starting new conversations)
  Future<ChatResult<MessageDto>> sendMessageToUser(
    String userId,
    String content,
  ) async {
    _sendingMessage = true;
    notifyListeners();

    final result = await _repository.sendMessage(
      recipientId: userId,
      content: content,
    );

    if (result.success && result.data != null) {
      // If this is the active conversation, add to messages
      if (_activeConversationUserId == userId) {
        _currentMessages = [result.data!, ..._currentMessages];
      }

      // Update or add conversation
      _updateConversationWithNewMessage(result.data!);
    }

    _sendingMessage = false;
    notifyListeners();

    return result;
  }

  /// Close the current conversation
  void closeConversation() {
    _activeConversationUserId = null;
    _currentMessages = [];
    _messagesPage = 0;
    _messagesHasMore = true;
    _messagesError = null;
    notifyListeners();
  }

  /// Handle new message received (from WebSocket)
  void onNewMessage(MessageDto message) {
    // If message is for active conversation, add it
    if (_activeConversationUserId == message.senderId ||
        _activeConversationUserId == message.recipientId) {
      _currentMessages = [message, ..._currentMessages];
    }

    // Update conversation list
    _updateConversationWithNewMessage(message);
    notifyListeners();
  }

  /// Update conversation with new message
  void _updateConversationWithNewMessage(MessageDto message) {
    final otherUserId = _activeConversationUserId == message.senderId
        ? message.recipientId
        : message.senderId;

    final index = _conversations.indexWhere((c) => c.oderId == otherUserId);

    if (index != -1) {
      // Update existing conversation
      final conversation = _conversations[index];
      _conversations[index] = conversation.copyWith(
        lastMessage: message,
        lastMessageAt: message.createdAt,
      );
      // Move to top
      final updated = _conversations.removeAt(index);
      _conversations.insert(0, updated);
    } else {
      // Create new conversation entry
      _conversations.insert(
        0,
        ConversationDto(
          oderId: otherUserId,
          otherUsername: message.senderUsername ?? 'Unknown',
          otherProfilePic: message.senderProfilePic,
          otherFirstName: message.senderFirstName,
          otherLastName: message.senderLastName,
          lastMessage: message,
          lastMessageAt: message.createdAt,
          unreadCount: 0,
        ),
      );
    }
  }

  /// Update unread count for a conversation
  void _updateConversationUnread(String userId, int count) {
    final index = _conversations.indexWhere((c) => c.oderId == userId);
    if (index != -1) {
      final oldCount = _conversations[index].unreadCount;
      _conversations[index] = _conversations[index].copyWith(unreadCount: count);
      _totalUnreadCount = _totalUnreadCount - oldCount + count;
      notifyListeners();
    }
  }

  /// Check if there's an existing conversation with a user
  bool hasConversationWith(String userId) {
    return _conversations.any((c) => c.oderId == userId);
  }

  /// Get conversation with a user
  ConversationDto? getConversationWith(String userId) {
    try {
      return _conversations.firstWhere((c) => c.oderId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Clear all data (for logout)
  void clear() {
    _conversations = [];
    _conversationsLoading = false;
    _conversationsError = null;

    _activeConversationUserId = null;
    _currentMessages = [];
    _messagesLoading = false;
    _messagesHasMore = true;
    _messagesPage = 0;
    _messagesError = null;

    _totalUnreadCount = 0;

    notifyListeners();
  }
}
