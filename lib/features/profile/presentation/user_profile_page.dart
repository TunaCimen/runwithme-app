import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_statistics.dart';
import '../../../core/utils/profile_pic_helper.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';
import '../../friends/data/friends_repository.dart';
import '../../friends/data/friends_api_client.dart';
import '../../chat/presentation/screens/chat_screen.dart';

/// Page to view another user's profile
class UserProfilePage extends StatefulWidget {
  final String userId;
  final String? username;

  const UserProfilePage({super.key, required this.userId, this.username});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _authService = AuthService();
  final _profileRepository = ProfileRepository();
  final _friendsRepository = FriendsRepository();

  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  // Friendship state
  FriendshipStatusType _friendshipStatus = FriendshipStatusType.none;
  String? _requestId; // For accepting/rejecting requests
  bool _isLoadingFriendship = false;

  // User statistics
  UserStatistics? _userStatistics;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFriendshipStatus();
    _loadUserStatistics();
  }

  Future<void> _loadProfile() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to view profiles';
      });
      return;
    }

    setState(() => _isLoading = true);

    final result = await _profileRepository.getProfile(
      widget.userId,
      accessToken: accessToken,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.profile != null) {
          _userProfile = result.profile;
        } else {
          _errorMessage = result.message;
        }
      });
    }
  }

  Future<void> _loadFriendshipStatus() async {
    final accessToken = _authService.accessToken;
    final currentUser = _authService.currentUser;
    if (accessToken == null || currentUser == null) return;

    // Don't check friendship status for own profile
    if (currentUser.userId == widget.userId) return;

    _friendsRepository.setAuthToken(accessToken);

    // First try the status endpoint
    final result = await _friendsRepository.checkFriendshipStatus(
      widget.userId,
    );
    if (mounted && result.success && result.data != null) {
      // Only update if we got a non-none status from the API
      if (result.data!.status != FriendshipStatusType.none) {
        setState(() {
          _friendshipStatus = result.data!.status;
          _requestId = result.data!.requestId;
        });
        return;
      }
    }

    // If status endpoint returned none, verify by checking friends and requests
    // This handles the case where the status endpoint doesn't exist or fails
    if (mounted) {
      await _verifyFriendshipViaLists();
    }
  }

  /// Verify friendship by checking friends list and pending requests
  Future<void> _verifyFriendshipViaLists() async {
    // Check friends list
    final friendsResult = await _friendsRepository.getFriends();
    if (friendsResult.success && friendsResult.data != null) {
      final isFriend = friendsResult.data!.content.any(
        (f) => f.friendUserId == widget.userId,
      );
      if (isFriend) {
        if (mounted) {
          setState(() => _friendshipStatus = FriendshipStatusType.friends);
        }
        return;
      }
    }

    // Check sent requests
    final sentResult = await _friendsRepository.getSentRequests();
    if (sentResult.success && sentResult.data != null) {
      final sentRequest = sentResult.data!.content.where(
        (r) => r.receiverId == widget.userId && r.status.name == 'pending',
      );
      if (sentRequest.isNotEmpty) {
        if (mounted) {
          setState(() {
            _friendshipStatus = FriendshipStatusType.pendingSent;
            _requestId = sentRequest.first.requestId;
          });
        }
        return;
      }
    }

    // Check received requests
    final receivedResult = await _friendsRepository.getReceivedRequests();
    if (receivedResult.success && receivedResult.data != null) {
      final receivedRequest = receivedResult.data!.content.where(
        (r) => r.senderId == widget.userId && r.status.name == 'pending',
      );
      if (receivedRequest.isNotEmpty) {
        if (mounted) {
          setState(() {
            _friendshipStatus = FriendshipStatusType.pendingReceived;
            _requestId = receivedRequest.first.requestId;
          });
        }
        return;
      }
    }

    // If none found, status is none (no relationship)
    if (mounted) {
      setState(() => _friendshipStatus = FriendshipStatusType.none);
    }
  }

  Future<void> _loadUserStatistics() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    final result = await _profileRepository.getUserStatistics(
      widget.userId,
      accessToken: accessToken,
    );

    if (mounted && result.success && result.statistics != null) {
      setState(() {
        _userStatistics = result.statistics;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    setState(() => _isLoadingFriendship = true);

    _friendsRepository.setAuthToken(accessToken);
    final result = await _friendsRepository.sendFriendRequest(
      receiverId: widget.userId,
    );

    if (mounted) {
      setState(() => _isLoadingFriendship = false);
      if (result.success) {
        setState(() {
          _friendshipStatus = FriendshipStatusType.pendingSent;
          _requestId = result.data?.requestId;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to send request')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null || _requestId == null) return;

    setState(() => _isLoadingFriendship = true);

    _friendsRepository.setAuthToken(accessToken);
    final result = await _friendsRepository.acceptRequest(_requestId!);

    if (mounted) {
      setState(() => _isLoadingFriendship = false);
      if (result.success) {
        setState(() => _friendshipStatus = FriendshipStatusType.friends);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to accept request')),
        );
      }
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: widget.userId,
          otherUserName: _userProfile?.fullName.isNotEmpty == true
              ? _userProfile!.fullName
              : widget.username ?? 'User',
          otherProfilePic: ProfilePicHelper.getProfilePicUrl(
            _userProfile?.profilePic,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final isOwnProfile = currentUser?.userId == widget.userId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with profile header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7ED321), Color(0xFF9AE64A)],
                  ),
                ),
                child: SafeArea(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _errorMessage != null
                      ? _buildErrorContent()
                      : _buildProfileHeader(),
                ),
              ),
            ),
          ),

          // Profile content
          SliverToBoxAdapter(
            child: _isLoading
                ? const SizedBox.shrink()
                : _errorMessage != null
                ? const SizedBox.shrink()
                : _buildProfileContent(isOwnProfile),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load profile',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7ED321),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final displayName = _userProfile?.fullName.isNotEmpty == true
        ? _userProfile!.fullName
        : widget.username ?? 'User';

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final profilePicUrl = ProfilePicHelper.getProfilePicUrl(
                _userProfile?.profilePic,
              );
              return CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: profilePicUrl != null
                    ? NetworkImage(profilePicUrl)
                    : null,
                child: profilePicUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7ED321),
                        ),
                      )
                    : null,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_userProfile?.expertLevel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _userProfile!.expertLevel!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(
                'Runs/wk',
                '${_userStatistics?.runsPerWeek ?? 0}',
              ),
              _buildStatColumn(
                'Distance',
                '${_userStatistics?.allTimeDistanceKm.toStringAsFixed(1) ?? '0'} km',
              ),
              _buildStatColumn(
                'Avg Pace',
                _userStatistics?.averagePace ?? '--',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildProfileContent(bool isOwnProfile) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action buttons (only for other users)
          if (!isOwnProfile) ...[
            Row(
              children: [
                Expanded(child: _buildFriendButton()),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _friendshipStatus == FriendshipStatusType.friends
                        ? _openChat
                        : null,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7ED321),
                      side: const BorderSide(color: Color(0xFF7ED321)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Bio section
          if (_userProfile?.pronouns != null) ...[
            _buildInfoSection('Pronouns', _userProfile!.pronouns!),
            const SizedBox(height: 16),
          ],

          // Activity section placeholder
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.directions_run, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendButton() {
    if (_isLoadingFriendship) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7ED321),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    switch (_friendshipStatus) {
      case FriendshipStatusType.friends:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check),
          label: const Text('Friends'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case FriendshipStatusType.pendingSent:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty),
          label: const Text('Pending'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[100],
            foregroundColor: Colors.orange[800],
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case FriendshipStatusType.pendingReceived:
        return ElevatedButton.icon(
          onPressed: _acceptFriendRequest,
          icon: const Icon(Icons.person_add),
          label: const Text('Accept'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7ED321),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case FriendshipStatusType.none:
        return ElevatedButton.icon(
          onPressed: _sendFriendRequest,
          icon: const Icon(Icons.person_add),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7ED321),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  Widget _buildInfoSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
