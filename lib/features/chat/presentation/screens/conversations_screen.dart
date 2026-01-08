import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../../friends/providers/friends_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/global_chat_provider.dart';
import '../widgets/conversation_tile.dart';
import 'package:runwithme_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:runwithme_app/features/chat/presentation/screens/mcp_integrated_chat_screen.dart';
import '../../../../core/utils/profile_pic_helper.dart';

/// Username used to identify the MCP AI assistant
const String mcpUsername = 'MCP';

/// Screen showing all conversations
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late ChatProvider _chatProvider;
  late FriendsProvider _friendsProvider;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // Use global chat provider for shared WebSocket connection
    _chatProvider = globalChatProvider;
    _friendsProvider = FriendsProvider();

    final token = _authService.accessToken;
    final currentUser = _authService.currentUser;

    if (token != null) {
      _friendsProvider.setAuthToken(token);

      if (currentUser != null) {
        _friendsProvider.setCurrentUserId(currentUser.userId);
        _chatProvider.setCurrentUserId(currentUser.userId);
      }

      // Use workaround: build conversations from friends list
      _loadConversationsFromFriends();
    }
  }

  /// Workaround: Load friends first, then build conversations from chat history
  Future<void> _loadConversationsFromFriends() async {
    // First load friends
    await _friendsProvider.loadFriends(refresh: true);

    // Then build conversations by checking chat history for each friend
    final currentUser = _authService.currentUser;
    if (currentUser != null && _friendsProvider.friends.isNotEmpty) {
      await _chatProvider.buildConversationsFromFriends(
        _friendsProvider.friends,
        currentUser.userId,
      );
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

          // Sort conversations to put MCP at the top
          final sortedConversations = _sortConversationsWithMcpFirst(
            _chatProvider.conversations,
          );

          return RefreshIndicator(
            onRefresh: _loadConversationsFromFriends,
            child: ListView.builder(
              itemCount: sortedConversations.length,
              itemBuilder: (context, index) {
                final conversation = sortedConversations[index];
                final isMcp = _isMcpConversation(conversation);

                return Column(
                  children: [
                    ConversationTile(
                      conversation: conversation,
                      isMcpAssistant: isMcp,
                      onTap: () => _openConversation(
                        conversation.oderId,
                        isMcp: isMcp,
                      ),
                    ),
                    if (index < sortedConversations.length - 1)
                      Divider(height: 1, indent: 72, color: Colors.grey[200]),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Check if a conversation is with the MCP assistant
  bool _isMcpConversation(dynamic conversation) {
    final username = conversation.otherUsername?.toString().toUpperCase() ?? '';
    final displayName =
        conversation.otherDisplayName?.toString().toUpperCase() ?? '';
    return username == mcpUsername.toUpperCase() ||
        displayName == mcpUsername.toUpperCase();
  }

  /// Sort conversations to put MCP at the top
  List<dynamic> _sortConversationsWithMcpFirst(List<dynamic> conversations) {
    final sorted = List.from(conversations);
    sorted.sort((a, b) {
      final aIsMcp = _isMcpConversation(a);
      final bIsMcp = _isMcpConversation(b);
      if (aIsMcp && !bIsMcp) return -1;
      if (!aIsMcp && bIsMcp) return 1;
      return 0; // Keep original order for non-MCP conversations
    });
    return sorted;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey[300],
            ),
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
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadConversationsFromFriends,
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

  void _openConversation(String userId, {bool isMcp = false}) {
    final conversation = _chatProvider.getConversationWith(userId);
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(
      conversation?.otherProfilePic,
    );

    if (isMcp) {
      // Open MCP integrated chat screen with reset button
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => McpIntegratedChatScreen(
            otherUserId: userId,
            otherUserName: conversation?.otherDisplayName ?? 'MCP',
            otherProfilePic: profilePicUrl,
          ),
        ),
      );
    } else {
      // Open regular chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            otherUserId: userId,
            otherUserName: conversation?.otherDisplayName ?? 'User',
            otherProfilePic: profilePicUrl,
          ),
        ),
      );
    }
  }

  void _showNewConversationSheet() {
    // Create a FriendsProvider to load friends
    final friendsProvider = FriendsProvider();
    final token = _authService.accessToken;
    final currentUser = _authService.currentUser;

    if (token != null) {
      friendsProvider.setAuthToken(token);
      if (currentUser != null) {
        friendsProvider.setCurrentUserId(currentUser.userId);
      }
      friendsProvider.loadFriends(refresh: true);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text(
                        'New Conversation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Friends list
                Expanded(
                  child: ListenableBuilder(
                    listenable: friendsProvider,
                    builder: (context, _) {
                      if (friendsProvider.friendsLoading &&
                          friendsProvider.friends.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (friendsProvider.friendsError != null &&
                          friendsProvider.friends.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  friendsProvider.friendsError!,
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => friendsProvider.loadFriends(
                                    refresh: true,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (friendsProvider.friends.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Friends Yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add friends to start chatting with them!',
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final currentUserId = currentUser?.userId ?? '';

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: friendsProvider.friends.length,
                        itemBuilder: (context, index) {
                          final friendship = friendsProvider.friends[index];
                          final friendId = friendship.getFriendId(
                            currentUserId,
                          );
                          final displayName = friendship.getFriendDisplayName(
                            currentUserId,
                          );
                          final username = friendship.getFriendUsername(
                            currentUserId,
                          );
                          final profilePic = friendship.getFriendProfilePic(
                            currentUserId,
                          );
                          final profilePicUrl =
                              ProfilePicHelper.getProfilePicUrl(profilePic);

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(
                                0xFF7ED321,
                              ).withValues(alpha: 0.2),
                              backgroundImage: profilePicUrl != null
                                  ? NetworkImage(profilePicUrl)
                                  : null,
                              child: profilePicUrl == null
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF7ED321),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: username != null
                                ? Text(
                                    '@$username',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF7ED321),
                            ),
                            onTap: () {
                              Navigator.pop(context); // Close the bottom sheet
                              _startConversationWithFriend(
                                friendId: friendId,
                                displayName: displayName,
                                profilePic: profilePicUrl,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startConversationWithFriend({
    required String friendId,
    required String displayName,
    String? profilePic,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: friendId,
          otherUserName: displayName,
          otherProfilePic: profilePic,
        ),
      ),
    );
  }
}
