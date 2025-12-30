import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';
import '../data/chat_websocket_service.dart';
import '../data/models/message_dto.dart';
import '../data/models/conversation_dto.dart';
import '../../friends/data/models/friendship_dto.dart';

// Debug flag - set to false for production
const bool _debugChat = false;
void _log(String message) {
  if (_debugChat) {
    debugPrint('[ChatProvider] $message');
  }
}

/// Provider for managing chat state
class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;
  final ChatWebSocketService _webSocketService = ChatWebSocketService();

  // WebSocket subscriptions
  StreamSubscription<MessageDto>? _newMessageSubscription;
  StreamSubscription<ReadReceiptPayload>? _readReceiptSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;

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

  // WebSocket connection state
  bool _isWebSocketConnected = false;

  // Current user ID (needed for determining message direction)
  String? _currentUserId;

  // Base URL for WebSocket
  final String _baseUrl;

  ChatProvider({
    String baseUrl = 'http://35.158.35.102:8080',
    ChatRepository? repository,
  })  : _baseUrl = baseUrl,
        _repository = repository ?? ChatRepository(baseUrl: baseUrl);

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
  bool get isWebSocketConnected => _isWebSocketConnected;

  /// Set authentication token and connect to WebSocket
  void setAuthToken(String token, {String? userId}) {
    _log(
      'setAuthToken called: token=${token.substring(0, token.length > 10 ? 10 : token.length)}...',
    );
    _repository.setAuthToken(token);
    _currentUserId = userId;

    // Connect to WebSocket
    _connectWebSocket(token);
  }

  /// Set current user ID
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Connect to WebSocket
  void _connectWebSocket(String token) {
    _log('Connecting to WebSocket...');

    // Cancel existing subscriptions
    _newMessageSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _connectionStateSubscription?.cancel();

    // Subscribe to WebSocket events
    _newMessageSubscription = _webSocketService.newMessageStream.listen(
      _handleNewMessage,
    );
    _readReceiptSubscription = _webSocketService.readReceiptStream.listen(
      _handleReadReceipt,
    );
    _connectionStateSubscription =
        _webSocketService.connectionStateStream.listen((connected) {
      _isWebSocketConnected = connected;
      _log('WebSocket connection state: $connected');
      notifyListeners();
    });

    // Connect
    _webSocketService.connect(token, baseUrl: _baseUrl);
  }

  /// Handle new message from WebSocket
  void _handleNewMessage(MessageDto message) {
    _log('Received new message via WebSocket: ${message.id}');

    // Determine if this is an incoming message (not from current user)
    final isIncoming = message.senderId != _currentUserId;

    // If message is for active conversation, add it
    if (_activeConversationUserId == message.senderId ||
        _activeConversationUserId == message.recipientId) {
      // Check if message already exists to avoid duplicates
      final exists = _currentMessages.any((m) => m.id == message.id);
      if (!exists) {
        _currentMessages = [message, ..._currentMessages];
      }
    }

    // Update conversation list
    _updateConversationWithNewMessage(message);

    // Update unread count if it's an incoming message and not in active conversation
    if (isIncoming && _activeConversationUserId != message.senderId) {
      _totalUnreadCount++;
    }

    notifyListeners();
  }

  /// Handle read receipt from WebSocket
  void _handleReadReceipt(ReadReceiptPayload receipt) {
    _log(
      'Received read receipt: ${receipt.messageIds.length} messages read by ${receipt.readByUsername}',
    );

    // Update messages in current conversation
    _currentMessages = _currentMessages.map((msg) {
      if (receipt.messageIds.contains(msg.id)) {
        return msg.copyWith(isRead: true);
      }
      return msg;
    }).toList();

    notifyListeners();
  }

  /// Fetch unread count from API
  Future<void> fetchUnreadCount() async {
    _log('Fetching unread count...');
    final result = await _repository.getUnreadCount();
    if (result.success && result.data != null) {
      _totalUnreadCount = result.data!;
      _log('Unread count: $_totalUnreadCount');
      notifyListeners();
    }
  }

  /// Disconnect WebSocket
  void disconnectWebSocket() {
    _log('Disconnecting WebSocket...');
    _webSocketService.disconnect();
    _newMessageSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _isWebSocketConnected = false;
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

    _log(
      '  API result: success=${result.success}, errorCode=${result.errorCode}, message=${result.message}',
    );

    if (result.success && result.data != null) {
      final messages = result.data!;
      _log('  Got ${messages.length} total messages');

      // Build conversations from messages
      _conversations = _buildConversationsFromMessages(messages, currentUserId);
      _log('  Built ${_conversations.length} conversations');

      for (final c in _conversations) {
        _log(
          '    Conversation: otherId=${c.oderId}, otherUsername=${c.otherUsername}, otherDisplayName=${c.otherDisplayName}',
        );
      }
      // Sort by last message time (most recent first)
      _conversations.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      // Calculate total unread count
      _totalUnreadCount = _conversations.fold(
        0,
        (sum, c) => sum + c.unreadCount,
      );
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
  List<ConversationDto> _buildConversationsFromMessages(
    List<MessageDto> messages,
    String? currentUserId,
  ) {
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
          otherUsername:
              (isFromOther
                  ? message.senderUsername
                  : message.recipientUsername) ??
              'Unknown',
          otherProfilePic: isFromOther
              ? message.senderProfilePic
              : message.recipientProfilePic,
          otherFirstName: isFromOther
              ? message.senderFirstName
              : message.recipientFirstName,
          otherLastName: isFromOther
              ? message.senderLastName
              : message.recipientLastName,
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
        if (message.createdAt.isAfter(
          existing.lastMessageAt ?? DateTime(1970),
        )) {
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
  Future<void> buildConversationsFromFriends(
    List<FriendshipDto> friends,
    String currentUserId,
  ) async {
    _log('buildConversationsFromFriends called: ${friends.length} friends');

    if (_conversationsLoading) {
      _log('  -> Already loading, skipping');
      return;
    }

    _conversationsLoading = true;
    _conversationsError = null;
    _currentUserId = currentUserId;
    notifyListeners();

    final List<ConversationDto> builtConversations = [];
    int totalUnread = 0;

    // Check chat history for each friend
    for (final friend in friends) {
      final friendId = friend.getFriendId(currentUserId);
      final friendUsername = friend.getFriendUsername(currentUserId);
      final friendDisplayName = friend.getFriendDisplayName(currentUserId);
      final friendProfilePic = friend.getFriendProfilePic(currentUserId);

      _log('  Checking chat history with: $friendUsername ($friendId)');

      try {
        // Fetch more messages to calculate unread count
        final result = await _repository.getChatHistory(
          friendId,
          page: 0,
          size: 50, // Get more messages to calculate unread count
        );

        if (result.success &&
            result.data != null &&
            result.data!.content.isNotEmpty) {
          final messages = result.data!.content;
          final lastMessage = messages.first;

          // Calculate unread count - messages from friend that are not read
          int unreadCount = 0;
          for (final msg in messages) {
            if (msg.senderId == friendId && !msg.isRead) {
              unreadCount++;
            }
          }

          _log(
            '    -> Has ${messages.length} messages, unread: $unreadCount, last: "${lastMessage.content.substring(0, lastMessage.content.length > 20 ? 20 : lastMessage.content.length)}..."',
          );

          builtConversations.add(
            ConversationDto(
              oderId: friendId,
              otherUsername: friendUsername ?? friendDisplayName,
              otherProfilePic: friendProfilePic,
              otherFirstName: friend.friendFirstName,
              otherLastName: friend.friendLastName,
              lastMessage: lastMessage,
              lastMessageAt: lastMessage.createdAt,
              unreadCount: unreadCount,
            ),
          );

          totalUnread += unreadCount;
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
    _totalUnreadCount = totalUnread;
    _log('  Built ${_conversations.length} conversations, total unread: $totalUnread');

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

    // Mark all unread messages in this conversation as read
    await markConversationMessagesAsRead(userId);
    _log(
      '  openConversation complete: ${_currentMessages.length} messages loaded',
    );
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationMessagesAsRead(String otherUserId) async {
    _log('markConversationMessagesAsRead called: userId=$otherUserId');

    // Get unread message IDs from current messages
    final unreadMessageIds = _currentMessages
        .where((m) => !m.isRead && m.senderId == otherUserId)
        .map((m) => m.id)
        .toList();

    if (unreadMessageIds.isEmpty) {
      _log('  No unread messages to mark as read');
      return;
    }

    _log('  Marking ${unreadMessageIds.length} messages as read');

    // Call API to mark messages as read
    final result = await _repository.markAsRead(messageIds: unreadMessageIds);

    if (result.success) {
      // Update local messages
      _currentMessages = _currentMessages.map((m) {
        if (unreadMessageIds.contains(m.id)) {
          return m.copyWith(isRead: true);
        }
        return m;
      }).toList();

      // Update conversation unread count
      _updateConversationUnread(otherUserId, 0);

      _log('  Messages marked as read successfully');
    } else {
      _log('  Failed to mark messages as read: ${result.message}');
    }
  }

  /// Load messages for the current conversation
  Future<void> loadMessages({bool refresh = false}) async {
    _log(
      'loadMessages called: refresh=$refresh, activeConversationUserId=$_activeConversationUserId',
    );

    if (_activeConversationUserId == null || _messagesLoading) {
      _log(
        '  -> Skipping: activeConversationUserId=$_activeConversationUserId, messagesLoading=$_messagesLoading',
      );
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

    _log(
      '  API result: success=${result.success}, errorCode=${result.errorCode}, message=${result.message}',
    );

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
    _log(
      'sendMessage called: content="${content.substring(0, content.length > 20 ? 20 : content.length)}...", activeConversationUserId=$_activeConversationUserId',
    );

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

    _log(
      '  API result: success=${result.success}, errorCode=${result.errorCode}, message=${result.message}',
    );

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
      _conversations[index] = _conversations[index].copyWith(
        unreadCount: count,
      );
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
    // Disconnect WebSocket
    disconnectWebSocket();

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
    _currentUserId = null;

    notifyListeners();
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}
