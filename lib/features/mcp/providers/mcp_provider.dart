import 'package:flutter/foundation.dart';
import '../data/mcp_repository.dart';
import '../data/models/mcp_message_dto.dart';

/// Provider for MCP (AI Assistant) chat state management
class McpProvider extends ChangeNotifier {
  final McpRepository _repository;

  // Messages state
  List<McpMessageDto> _messages = [];
  bool _messagesLoading = false;
  String? _messagesError;

  // Sending state
  bool _sendingMessage = false;

  // Resetting state
  bool _resettingHistory = false;

  McpProvider({McpRepository? repository})
      : _repository = repository ?? McpRepository();

  // Getters
  List<McpMessageDto> get messages => _messages;
  bool get messagesLoading => _messagesLoading;
  String? get messagesError => _messagesError;
  bool get sendingMessage => _sendingMessage;
  bool get resettingHistory => _resettingHistory;
  bool get hasMessages => _messages.isNotEmpty;

  /// Set authorization token
  void setAuthToken(String token) {
    _repository.setAuthToken(token);
  }

  /// Load chat history
  Future<void> loadHistory({bool refresh = false}) async {
    if (_messagesLoading) return;

    if (refresh) {
      _messages = [];
    }

    _messagesLoading = true;
    _messagesError = null;
    notifyListeners();

    final result = await _repository.getChatHistory();

    if (result.success) {
      _messages = result.data ?? [];
      // Sort messages by timestamp (oldest first for display)
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else {
      _messagesError = result.message;
    }

    _messagesLoading = false;
    notifyListeners();
  }

  /// Send a message to MCP agent
  Future<McpResult<McpMessageDto>> sendMessage(String content) async {
    if (_sendingMessage || content.trim().isEmpty) {
      return McpResult.failure(message: 'Cannot send empty message');
    }

    _sendingMessage = true;
    notifyListeners();

    // Add user message locally first
    final userMessage = McpMessageDto(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isFromUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    notifyListeners();

    // Send to API and get response
    final result = await _repository.sendMessage(content);

    if (result.success && result.data != null) {
      _messages.add(result.data!);
    } else {
      // Add error message as response
      _messages.add(McpMessageDto(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: result.message ?? 'Failed to get response',
        isFromUser: false,
        timestamp: DateTime.now(),
      ));
    }

    _sendingMessage = false;
    notifyListeners();

    return result;
  }

  /// Reset conversation history
  Future<McpResult<void>> resetHistory() async {
    if (_resettingHistory) {
      return McpResult.failure(message: 'Already resetting');
    }

    _resettingHistory = true;
    notifyListeners();

    final result = await _repository.resetHistory();

    if (result.success) {
      // Clear local messages
      _messages = [];
    }

    _resettingHistory = false;
    notifyListeners();

    return result;
  }

  /// Clear local messages without calling API
  void clearLocalMessages() {
    _messages = [];
    notifyListeners();
  }

  /// Get the last message for preview
  McpMessageDto? get lastMessage => _messages.isNotEmpty ? _messages.last : null;

  /// Get last message preview text
  String get lastMessagePreview {
    if (_messages.isEmpty) return 'Ask me anything about running!';
    final msg = _messages.last;
    final content = msg.content;
    if (content.length > 50) {
      return '${content.substring(0, 47)}...';
    }
    return content;
  }

  /// Get last message time formatted
  String get lastMessageTime {
    if (_messages.isEmpty) return '';

    final lastMessageAt = _messages.last.timestamp;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      lastMessageAt.year,
      lastMessageAt.month,
      lastMessageAt.day,
    );

    if (messageDate == today) {
      return '${lastMessageAt.hour.toString().padLeft(2, '0')}:${lastMessageAt.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(lastMessageAt).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[lastMessageAt.weekday - 1];
    } else {
      return '${lastMessageAt.day}/${lastMessageAt.month}';
    }
  }
}

/// Global MCP provider instance
McpProvider? _globalMcpProvider;

McpProvider get globalMcpProvider {
  _globalMcpProvider ??= McpProvider();
  return _globalMcpProvider!;
}
