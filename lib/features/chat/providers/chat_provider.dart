import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';
import '../data/models/message_dto.dart';
import '../data/models/conversation_dto.dart';
import '../../friends/data/models/friendship_dto.dart';

// Debug flag
const bool _debugChat = true;
void _log(String message) {
  if (_debugChat) {
    debugPrint('[ChatProvider] $message');
  }
}

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
    _log('setAuthToken called: token=${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    _repository.setAuthToken(token);
  }

  /// Load all conversations by fetching all messages and grouping by user
  Future<void> loadConversations({String? currentUserId}) async {
    _log('loadConversations called');

    if (_conversationsLoading) {
      _log('  -> Already loading, skipping');
      return;
    }

    _conversationsLoading = true;
    _conversationsError = null;
    notifyListeners();

    final result = await _repository.getAllMessages();

    _log('  API result: success=${result.success}, errorCode=${result.errorCode}, message=${result.message}');

    if (result.success && result.data != null) {
      final messages = result.data!;
      _log('  Got ${messages.length} total messages');

      // Build conversations from messages
      _conversations = _buildConversationsFromMessages(messages, currentUserId);
      _log('  Built ${_conversations.length} conversations');

      for (final c in _conversations) {
        _log('    Conversation: otherId=${c.oderId}, otherUsername=${c.otherUsername}, otherDisplayName=${c.otherDisplayName}');
      }
      // Sort by last message time (most recent first)
      _conversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      // Calculate total unread count
      _totalUnreadCount = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } else if (result.errorCode == 'NOT_FOUND') {
      // No conversations exist yet - this is OK, just show empty state
      _log('  No conversations found (404) - treating as empty list');
      _conversations = [];
      _totalUnreadCount = 0;
      // Don't set error - this is a normal case for new users
    } else {
      _log('  Error loading conversations: ${result.message}');
      _conversationsError = result.message;
    }

    _conversationsLoading = false;
    notifyListeners();
  }

  /// Build conversations list from messages
  List<ConversationDto> _buildConversationsFromMessages(List<MessageDto> messages, String? currentUserId) {
    final Map<String, ConversationDto> conversationMap = {};

    for (final message in messages) {
      // Determine the other user in the conversation
      final otherUserId = message.senderId == currentUserId
          ? message.recipientId
          : message.senderId;

      if (!conversationMap.containsKey(otherUserId)) {
        // Create new conversation entry
        final isFromOther = message.senderId != currentUserId;
        conversationMap[otherUserId] = ConversationDto(
          oderId: otherUserId,
          otherUsername: (isFromOther ? message.senderUsername : message.recipientUsername) ?? 'Unknown',
          otherProfilePic: isFromOther ? message.senderProfilePic : message.recipientProfilePic,
          otherFirstName: isFromOther ? message.senderFirstName : message.recipientFirstName,
          otherLastName: isFromOther ? message.senderLastName : message.recipientLastName,
          lastMessage: message,
          lastMessageAt: message.createdAt,
          unreadCount: (!message.isRead && isFromOther) ? 1 : 0,
        );
      } else {
        // Update unread count if this is an unread message from the other user
        final existing = conversationMap[otherUserId]!;
        final isFromOther = message.senderId != currentUserId;
        if (!message.isRead && isFromOther) {
          conversationMap[otherUserId] = existing.copyWith(
            unreadCount: existing.unreadCount + 1,
          );
        }
        // Update last message if this one is more recent
        if (message.createdAt.isAfter(existing.lastMessageAt ?? DateTime(1970))) {
          conversationMap[otherUserId] = existing.copyWith(
            lastMessage: message,
            lastMessageAt: message.createdAt,
          );
        }
      }
    }

    return conversationMap.values.toList();
  }

  /// Build conversations list from friends by checking chat history for each
  /// This is a workaround until the backend implements GET /conversations
  Future<void> buildConversationsFromFriends(List<FriendshipDto> friends, String currentUserId) async {
    _log('buildConversationsFromFriends called: ${friends.length} friends');

    if (_conversationsLoading) {
      _log('  -> Already loading, skipping');
      return;
    }

    _conversationsLoading = true;
    _conversationsError = null;
    notifyListeners();

    final List<ConversationDto> builtConversations = [];

    // Check chat history for each friend
    for (final friend in friends) {
      final friendId = friend.getFriendId(currentUserId);
      final friendUsername = friend.getFriendUsername(currentUserId);
      final friendDisplayName = friend.getFriendDisplayName(currentUserId);
      final friendProfilePic = friend.getFriendProfilePic(currentUserId);

      _log('  Checking chat history with: $friendUsername ($friendId)');

      try {
        final result = await _repository.getChatHistory(friendId, page: 0, size: 1);

        if (result.success && result.data != null && result.data!.content.isNotEmpty) {
          final lastMessage = result.data!.content.first;
          _log('    -> Has messages, last: "${lastMessage.content.substring(0, lastMessage.content.length > 20 ? 20 : lastMessage.content.length)}..."');

          builtConversations.add(ConversationDto(
            oderId: friendId,
            otherUsername: friendUsername ?? friendDisplayName,
            otherProfilePic: friendProfilePic,
            otherFirstName: friend.friendFirstName,
            otherLastName: friend.friendLastName,
            lastMessage: lastMessage,
            lastMessageAt: lastMessage.createdAt,
            unreadCount: 0, // We don't have this info without the backend endpoint
          ));
        } else if (result.errorCode == 'NOT_FOUND') {
          _log('    -> No messages yet');
        } else {
          _log('    -> Error: ${result.message}');
        }
      } catch (e) {
        _log('    -> Exception: $e');
      }
    }

    // Sort by last message time (most recent first)
    builtConversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    _conversations = builtConversations;
    _totalUnreadCount = 0; // We don't have unread counts without backend
    _log('  Built ${_conversations.length} conversations from friends');

    _conversationsLoading = false;
    notifyListeners();
  }

  /// Open a conversation with a user
  Future<void> openConversation(String userId) async {
    _log('openConversation called: userId=$userId');

    _activeConversationUserId = userId;
    _currentMessages = [];
    _messagesPage = 0;
    _messagesHasMore = true;
    _messagesError = null;

    await loadMessages(refresh: true);

    // Mark conversation as read (ignore errors for new conversations)
    _log('  Marking conversation as read...');
    await _repository.markConversationAsRead(userId);
    _updateConversationUnread(userId, 0);
    _log('  openConversation complete: ${_currentMessages.length} messages loaded');
  }

  /// Load messages for the current conversation
  Future<void> loadMessages({bool refresh = false}) async {
    _log('loadMessages called: refresh=$refresh, activeConversationUserId=$_activeConversationUserId');

    if (_activeConversationUserId == null || _messagesLoading) {
      _log('  -> Skipping: activeConversationUserId=$_activeConversationUserId, messagesLoading=$_messagesLoading');
      return;
    }

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

    _log('  API result: success=${result.success}, errorCode=${result.errorCode}, message=${result.message}');

    if (result.success && result.data != null) {
      _log('  Got ${result.data!.content.length} messages');
      if (refresh) {
        _currentMessages = result.data!.content;
      } else {
        // Append older messages at the end
        _currentMessages = [..._currentMessages, ...result.data!.content];
      }
      _messagesHasMore = !result.data!.last;
      _messagesPage++;
    } else if (result.errorCode == 'NOT_FOUND') {
      // No conversation exists yet - this is OK, just show empty state
      _log('  No conversation found (404) - treating as empty conversation');
      if (refresh) {
        _currentMessages = [];
      }
      _messagesHasMore = false;
      // Don't set error - this is a normal case for new conversations
    } else {
      _log('  Error loading messages: ${result.message}');
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
    _log('sendMessage called: content="${content.substring(0, content.length > 20 ? 20 : content.length)}...", activeConversationUserId=$_activeConversationUserId');

    if (_activeConversationUserId == null) {
      _log('  -> Error: No active conversation');
      return ChatResult.failure(message: 'No active conversation');
    }

    _sendingMessage = true;
    notifyListeners();

    final result = await _repository.sendMessage(
      recipientId: _activeConversationUserId!,
      content: content,
    );

    _log('  API result: success=${result.success}, errorCode=${result.errorCode}, message=${result.message}');

    if (result.success && result.data != null) {
      _log('  Message sent successfully, id=${result.data!.id}');
      // Add message to the beginning of the list (newest first)
      _currentMessages = [result.data!, ..._currentMessages];

      // Update conversation in the list
      _updateConversationWithNewMessage(result.data!);
    } else {
      _log('  Failed to send message: ${result.message}');
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
