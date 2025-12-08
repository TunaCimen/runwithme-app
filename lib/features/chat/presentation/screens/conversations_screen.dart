import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../providers/chat_provider.dart';
import '../widgets/conversation_tile.dart';
import 'package:runwithme_app/features/chat/presentation/screens/chat_screen.dart';

/// Screen showing all conversations
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late ChatProvider _chatProvider;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider();

    final token = _authService.accessToken;
    if (token != null) {
      _chatProvider.setAuthToken(token);
      _chatProvider.loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.black87),
            onPressed: _showNewConversationSheet,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _chatProvider,
        builder: (context, _) {
          if (_chatProvider.conversationsLoading &&
              _chatProvider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_chatProvider.conversationsError != null &&
              _chatProvider.conversations.isEmpty) {
            return _buildErrorState();
          }

          if (_chatProvider.conversations.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => _chatProvider.loadConversations(),
            child: ListView.builder(
              itemCount: _chatProvider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = _chatProvider.conversations[index];
                return Column(
                  children: [
                    ConversationTile(
                      conversation: conversation,
                      onTap: () => _openConversation(conversation.oderId),
                    ),
                    if (index < _chatProvider.conversations.length - 1)
                      Divider(
                        height: 1,
                        indent: 72,
                        color: Colors.grey[200],
                      ),
                  ],
                );
              },
            ),
          );
        },
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
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start a conversation with other runners!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showNewConversationSheet,
              icon: const Icon(Icons.add),
              label: const Text('New Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED321),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 24),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _chatProvider.conversationsError ?? 'Failed to load messages',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _chatProvider.loadConversations(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED321),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConversation(String userId) {
    final conversation = _chatProvider.getConversationWith(userId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: userId,
          otherUserName: conversation?.otherDisplayName ?? 'User',
          otherProfilePic: conversation?.otherProfilePic,
        ),
      ),
    );
  }

  void _showNewConversationSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Conversation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start a conversation with a friend or another runner.',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Select a friend from your\nfriends list to start chatting',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
