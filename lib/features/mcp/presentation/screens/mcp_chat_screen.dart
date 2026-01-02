import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../providers/mcp_provider.dart';
import '../widgets/mcp_message_bubble.dart';

/// Screen for chatting with the MCP AI Assistant
class McpChatScreen extends StatefulWidget {
  const McpChatScreen({super.key});

  @override
  State<McpChatScreen> createState() => _McpChatScreenState();
}

class _McpChatScreenState extends State<McpChatScreen> {
  late McpProvider _mcpProvider;
  final _authService = AuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _mcpProvider = globalMcpProvider;

    final token = _authService.accessToken;
    if (token != null) {
      _mcpProvider.setAuthToken(token);
      _mcpProvider.loadHistory();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MCP',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
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
          ListenableBuilder(
            listenable: _mcpProvider,
            builder: (context, _) {
              return IconButton(
                icon: _mcpProvider.resettingHistory
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.black87),
                onPressed: _mcpProvider.resettingHistory ? null : _resetChat,
                tooltip: 'New Chat',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _mcpProvider,
              builder: (context, _) {
                if (_mcpProvider.messagesLoading &&
                    _mcpProvider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_mcpProvider.messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _mcpProvider.messages.length,
                  itemBuilder: (context, index) {
                    // Since list is reversed, we need to reverse the index
                    final reversedIndex =
                        _mcpProvider.messages.length - 1 - index;
                    final message = _mcpProvider.messages[reversedIndex];

                    return McpMessageBubble(
                      message: message,
                      isFromUser: message.isFromUser,
                    );
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
            listenable: _mcpProvider,
            builder: (context, _) {
              return GestureDetector(
                onTap: _mcpProvider.sendingMessage ? null : _sendMessage,
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
                  child: _mcpProvider.sendingMessage
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
    _scrollToBottom();

    final result = await _mcpProvider.sendMessage(text);
    _scrollToBottom();

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
          'This will clear your conversation history with MCP. Are you sure?',
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
      final result = await _mcpProvider.resetHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Conversation reset!'
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
