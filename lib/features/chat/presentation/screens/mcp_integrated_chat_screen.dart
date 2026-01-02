import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../../mcp/data/mcp_repository.dart';
import '../../providers/chat_provider.dart';
import '../../providers/global_chat_provider.dart';
import '../widgets/message_bubble.dart';

/// Chat screen for the MCP AI assistant
/// Uses regular chat for messages but adds AI styling and reset functionality
class McpIntegratedChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherProfilePic;

  const McpIntegratedChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherProfilePic,
  });

  @override
  State<McpIntegratedChatScreen> createState() =>
      _McpIntegratedChatScreenState();
}

class _McpIntegratedChatScreenState extends State<McpIntegratedChatScreen> {
  late ChatProvider _chatProvider;
  final _authService = AuthService();
  final _mcpRepository = McpRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isResetting = false;

  @override
  void initState() {
    super.initState();

    // Use the global chat provider to benefit from WebSocket connection
    _chatProvider = globalChatProvider;

    final token = _authService.accessToken;
    final currentUser = _authService.currentUser;

    if (token != null) {
      _mcpRepository.setAuthToken(token);

      if (currentUser != null) {
        _chatProvider.setCurrentUserId(currentUser.userId);
      }
      _chatProvider.openConversation(widget.otherUserId);
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatProvider.closeConversation();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _chatProvider.loadMoreMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.userId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // AI-styled avatar with gradient and robot icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7ED321), Color(0xFF5DB91C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7ED321).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(
                            color: Color(0xFF7ED321),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Reset button
          IconButton(
            icon: _isResetting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isResetting ? null : _resetChat,
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _chatProvider,
              builder: (context, _) {
                if (_chatProvider.messagesLoading &&
                    _chatProvider.currentMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_chatProvider.messagesError != null &&
                    _chatProvider.currentMessages.isEmpty) {
                  return _buildErrorState();
                }

                if (_chatProvider.currentMessages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _chatProvider.currentMessages.length +
                      (_chatProvider.messagesLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_chatProvider.messagesLoading &&
                        index == _chatProvider.currentMessages.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final message = _chatProvider.currentMessages[index];
                    final isSent = message.senderId == currentUserId;

                    return MessageBubble(message: message, isSent: isSent);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7ED321), Color(0xFF5DB91C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MCP Assistant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hi! I\'m your running assistant.\nAsk me anything about training, routes, or your performance!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('Training tips'),
                _buildSuggestionChip('Route recommendations'),
                _buildSuggestionChip('Pace analysis'),
                _buildSuggestionChip('Recovery advice'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
      backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.1),
      labelStyle: const TextStyle(
        color: Color(0xFF7ED321),
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: Color(0xFF7ED321), width: 1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _chatProvider.messagesError ?? 'Failed to load messages',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _chatProvider.loadMessages(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask MCP anything...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: _chatProvider,
            builder: (context, _) {
              return GestureDetector(
                onTap: _chatProvider.sendingMessage ? null : _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7ED321), Color(0xFF5DB91C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: _chatProvider.sendingMessage
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 22),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final result = await _chatProvider.sendMessage(text);
    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to send message')),
      );
    }
  }

  Future<void> _resetChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: const Text(
          'This will reset the AI\'s conversation context. Your message history will remain, but MCP will respond as if starting fresh. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7ED321),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isResetting = true);

      final result = await _mcpRepository.resetHistory();

      if (mounted) {
        setState(() => _isResetting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'AI context reset! MCP will start fresh.'
                  : result.message ?? 'Failed to reset',
            ),
            backgroundColor:
                result.success ? const Color(0xFF7ED321) : Colors.red,
          ),
        );
      }
    }
  }
}
