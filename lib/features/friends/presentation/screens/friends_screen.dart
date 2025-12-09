import 'package:flutter/material.dart';
import '../../../auth/data/auth_service.dart';
import '../../data/models/friendship_dto.dart';
import '../../providers/friends_provider.dart';
import '../widgets/friend_list_tile.dart';
import '../widgets/friend_request_card.dart';
import '../widgets/sent_request_tile.dart';
import '../../../profile/presentation/user_profile_page.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../../core/utils/profile_pic_helper.dart';

/// Main screen for managing friends, requests, and sent requests
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FriendsProvider _friendsProvider;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _friendsProvider = FriendsProvider();

    final token = _authService.accessToken;
    final currentUser = _authService.currentUser;
    debugPrint('[FriendsScreen] initState: token=${token != null ? "present" : "null"}, currentUser=${currentUser?.userId}');
    if (token != null) {
      _friendsProvider.setAuthToken(token);
      if (currentUser != null) {
        _friendsProvider.setCurrentUserId(currentUser.userId);
        debugPrint('[FriendsScreen] Set currentUserId: ${currentUser.userId}');
      } else {
        debugPrint('[FriendsScreen] WARNING: No current user!');
      }
      _friendsProvider.loadAll();
    } else {
      debugPrint('[FriendsScreen] WARNING: No auth token!');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Friends',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7ED321),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF7ED321),
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
              child: ListenableBuilder(
                listenable: _friendsProvider,
                builder: (context, _) {
                  final count = _friendsProvider.receivedRequestsCount;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Requests'),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(text: 'Sent'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _friendsProvider,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(),
              _buildRequestsTab(),
              _buildSentTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friendsProvider.friendsLoading && _friendsProvider.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsProvider.friendsError != null &&
        _friendsProvider.friends.isEmpty) {
      return _buildErrorState(
        _friendsProvider.friendsError!,
        () => _friendsProvider.loadFriends(refresh: true),
      );
    }

    if (_friendsProvider.friends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Friends Yet',
        message: 'Start connecting with other runners!',
      );
    }

    final currentUserId = _authService.currentUser?.userId ?? '';

    return RefreshIndicator(
      onRefresh: () => _friendsProvider.loadFriends(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _friendsProvider.friends.length +
            (_friendsProvider.friendsHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _friendsProvider.friends.length) {
            _friendsProvider.loadMoreFriends();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final friendship = _friendsProvider.friends[index];
          return _buildFriendTile(friendship, currentUserId);
        },
      ),
    );
  }

  Widget _buildFriendTile(FriendshipDto friendship, String currentUserId) {
    final friendId = friendship.getFriendId(currentUserId);
    final displayName = friendship.getFriendDisplayName(currentUserId);
    final username = friendship.getFriendUsername(currentUserId);
    final profilePic = friendship.getFriendProfilePic(currentUserId);
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(profilePic);

    return Dismissible(
      key: Key(friendship.friendshipId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemoveFriend(friendship, currentUserId),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.person_remove, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FriendListTile(
          displayName: displayName,
          username: username,
          profilePicUrl: profilePicUrl,
          onTap: () => _navigateToProfile(friendId, displayName: displayName, username: username),
          trailing: [
            IconButton(
              icon: Icon(Icons.message_outlined, color: Colors.grey[600]),
              onPressed: () => _startChat(friendId, displayName: displayName, profilePicUrl: profilePicUrl),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmRemoveFriend(
    FriendshipDto friendship,
    String currentUserId,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${friendship.getFriendDisplayName(currentUserId)} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (result == true) {
      final removeResult =
          await _friendsProvider.removeFriend(friendship.friendshipId);
      if (mounted && !removeResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(removeResult.message ?? 'Failed to remove friend')),
        );
        return false;
      }
      return true;
    }
    return false;
  }

  Widget _buildRequestsTab() {
    if (_friendsProvider.receivedRequestsLoading &&
        _friendsProvider.receivedRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsProvider.receivedRequestsError != null &&
        _friendsProvider.receivedRequests.isEmpty) {
      return _buildErrorState(
        _friendsProvider.receivedRequestsError!,
        () => _friendsProvider.loadReceivedRequests(refresh: true),
      );
    }

    if (_friendsProvider.receivedRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mail_outline,
        title: 'No Pending Requests',
        message: 'Friend requests you receive will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _friendsProvider.loadReceivedRequests(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _friendsProvider.receivedRequests.length +
            (_friendsProvider.receivedRequestsHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _friendsProvider.receivedRequests.length) {
            _friendsProvider.loadMoreReceivedRequests();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final request = _friendsProvider.receivedRequests[index];
          return FriendRequestCard(
            request: request,
            isLoading: _friendsProvider.respondingToRequest,
            onAccept: () => _acceptRequest(request.requestId),
            onReject: () => _rejectRequest(request.requestId),
            onTap: () => _navigateToProfile(
              request.senderId,
              displayName: request.senderDisplayName,
              username: request.senderUsername,
            ),
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    final result = await _friendsProvider.acceptRequest(requestId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Friend request accepted!'
                : result.message ?? 'Failed to accept request',
          ),
          backgroundColor: result.success ? const Color(0xFF7ED321) : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final result = await _friendsProvider.rejectRequest(requestId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Friend request declined'
                : result.message ?? 'Failed to decline request',
          ),
        ),
      );
    }
  }

  Widget _buildSentTab() {
    if (_friendsProvider.sentRequestsLoading &&
        _friendsProvider.sentRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsProvider.sentRequestsError != null &&
        _friendsProvider.sentRequests.isEmpty) {
      return _buildErrorState(
        _friendsProvider.sentRequestsError!,
        () => _friendsProvider.loadSentRequests(refresh: true),
      );
    }

    if (_friendsProvider.sentRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send_outlined,
        title: 'No Sent Requests',
        message: 'Friend requests you send will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _friendsProvider.loadSentRequests(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _friendsProvider.sentRequests.length +
            (_friendsProvider.sentRequestsHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _friendsProvider.sentRequests.length) {
            _friendsProvider.loadMoreSentRequests();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final request = _friendsProvider.sentRequests[index];
          return SentRequestTile(
            request: request,
            isLoading: _friendsProvider.sendingRequest,
            onCancel: () => _cancelRequest(request.requestId),
            onTap: () => _navigateToProfile(
              request.receiverId,
              displayName: request.receiverDisplayName,
              username: request.receiverUsername,
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancelRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this friend request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _friendsProvider.cancelRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Friend request cancelled'
                  : result.message ?? 'Failed to cancel request',
            ),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
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
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
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

  void _navigateToProfile(String userId, {String? username, String? displayName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          userId: userId,
          username: displayName ?? username,
        ),
      ),
    );
  }

  void _startChat(String friendId, {String? displayName, String? profilePicUrl}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: friendId,
          otherUserName: displayName ?? 'User',
          otherProfilePic: profilePicUrl,
        ),
      ),
    );
  }
}
