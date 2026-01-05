import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_statistics.dart';
import '../../../core/models/run_session.dart';
import '../../../core/models/route.dart' as route_model;
import '../../../core/utils/profile_pic_helper.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';
import '../../map/data/route_repository.dart';
import '../../feed/data/models/feed_post_dto.dart';
import '../../feed/data/feed_post_enricher.dart';
import '../../friends/data/friends_repository.dart';
import '../../friends/data/friends_api_client.dart';
import '../../chat/presentation/screens/chat_screen.dart';
import '../../feed/presentation/widgets/feed_post_card.dart';
import '../../feed/presentation/screens/post_detail_screen.dart';

typedef UserRoute = route_model.Route;

/// Page to view another user's profile
class UserProfilePage extends StatefulWidget {
  final String userId;
  final String? username;

  const UserProfilePage({super.key, required this.userId, this.username});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _profileRepository = ProfileRepository();
  final _friendsRepository = FriendsRepository();
  final _routeRepository = RouteRepository();
  final _postEnricher = FeedPostEnricher();

  late TabController _tabController;

  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  // Friendship state
  FriendshipStatusType _friendshipStatus = FriendshipStatusType.none;
  String? _requestId;
  bool _isLoadingFriendship = false;

  // User statistics
  UserStatistics? _userStatistics;

  // User data (routes, runs, posts)
  List<UserRoute> _userRoutes = [];
  List<RunSession> _userRuns = [];
  List<FeedPostDto> _userPosts = [];
  bool _isLoadingData = false;
  bool _isLoadingRoutes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
    _loadFriendshipStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

          // Only load additional data if profile is not restricted
          if (_userProfile?.isRestricted != true) {
            _loadUserStatistics();
            _loadUserData();
          }
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

    if (currentUser.userId == widget.userId) return;

    _friendsRepository.setAuthToken(accessToken);

    final result = await _friendsRepository.checkFriendshipStatus(
      widget.userId,
    );
    if (mounted && result.success && result.data != null) {
      if (result.data!.status != FriendshipStatusType.none) {
        setState(() {
          _friendshipStatus = result.data!.status;
          _requestId = result.data!.requestId;
        });
        return;
      }
    }

    if (mounted) {
      await _verifyFriendshipViaLists();
    }
  }

  Future<void> _verifyFriendshipViaLists() async {
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

  Future<void> _loadUserData() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    setState(() => _isLoadingData = true);

    // Load runs and posts in parallel
    final results = await Future.wait([
      _profileRepository.getUserRunSessions(
        widget.userId,
        accessToken: accessToken,
      ),
      _profileRepository.getUserPosts(widget.userId, accessToken: accessToken),
    ]);

    if (mounted) {
      final runsResult = results[0] as UserRunsResult;
      if (runsResult.success) {
        setState(() {
          _userRuns = runsResult.runs;
        });
      }

      final postsResult = results[1] as UserPostsResult;
      if (postsResult.success) {
        // Enrich posts with route/run data from API
        final enrichedPosts = await _postEnricher.enrichPosts(
          postsResult.posts,
          accessToken: accessToken,
        );

        if (mounted) {
          setState(() {
            _userPosts = enrichedPosts;
          });
        }
      }
    }

    // Load routes separately using the public routes approach
    await _loadUserRoutes();

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  /// Load user routes from public routes filtered by user ID
  Future<void> _loadUserRoutes() async {
    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    setState(() => _isLoadingRoutes = true);

    // Get public routes and filter by user ID
    final result = await _routeRepository.getPublicRoutes(
      page: 0,
      size: 50,
      accessToken: accessToken,
    );

    if (result.success && result.routes != null) {
      // Filter routes by this user's ID
      final userRoutes = result.routes!
          .where((r) => r.creatorId == widget.userId)
          .toList();

      // Fetch full route details for map display
      final fullRoutes = await _routeRepository.fetchFullRouteDetails(
        routes: userRoutes,
        accessToken: accessToken,
      );

      if (mounted) {
        setState(() {
          _userRoutes = fullRoutes;
          _userRoutes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoadingRoutes = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingRoutes = false);
      }
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
        // Reload profile to get full data after becoming friends
        _loadProfile();
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
          otherUserName: _userProfile?.displayName ?? widget.username ?? 'User',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7ED321)),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : _userProfile?.isRestricted == true
          ? _buildPrivateProfileView()
          : _buildFullProfileView(isOwnProfile),
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to load profile',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProfile,
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

  Widget _buildPrivateProfileView() {
    final displayName = _userProfile?.displayName ?? widget.username ?? 'User';
    final currentUser = _authService.currentUser;
    final isOwnProfile = currentUser?.userId == widget.userId;

    return CustomScrollView(
      slivers: [
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7ED321),
                        ),
                      ),
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Private Profile',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Action buttons (only for other users)
                if (!isOwnProfile) ...[
                  Row(
                    children: [
                      Expanded(child: _buildFriendButton()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _friendshipStatus == FriendshipStatusType.friends
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
                  const SizedBox(height: 32),
                ],

                // Private profile message
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This Profile is Private',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Send a friend request to see their runs, routes, and posts.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullProfileView(bool isOwnProfile) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
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
                child: SafeArea(child: _buildProfileHeader()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Action buttons
                  if (!isOwnProfile) ...[
                    Row(
                      children: [
                        Expanded(child: _buildFriendButton()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _friendshipStatus ==
                                    FriendshipStatusType.friends
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
                    const SizedBox(height: 16),
                  ],

                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF7ED321),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF7ED321),
                tabs: [
                  Tab(text: 'Runs (${_userRuns.length})'),
                  Tab(text: 'Routes (${_userRoutes.length})'),
                  Tab(text: 'Posts (${_userPosts.length})'),
                ],
              ),
            ),
          ),
        ];
      },
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7ED321)),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildRunsTab(), _buildRoutesTab(), _buildPostsTab()],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final displayName = _userProfile?.displayName ?? widget.username ?? 'User';
    final pronouns = _userProfile?.pronouns;

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
          // Name with pronouns
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (pronouns != null && pronouns.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '($pronouns)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
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

  Widget _buildRunsTab() {
    if (_userRuns.isEmpty) {
      return _buildEmptyState(
        icon: Icons.directions_run,
        title: 'No Runs Yet',
        subtitle: 'This user hasn\'t recorded any runs.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userRuns.length,
      itemBuilder: (context, index) {
        final run = _userRuns[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF7ED321).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_run, color: Color(0xFF7ED321)),
            ),
            title: Text(
              run.formattedDate,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(run.formattedDistance),
                    const SizedBox(width: 16),
                    Text(run.formattedDuration),
                    const SizedBox(width: 16),
                    Text(run.formattedPace),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoutesTab() {
    if (_isLoadingRoutes) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7ED321)),
      );
    }

    if (_userRoutes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.route,
        title: 'No Saved Routes',
        subtitle: 'This user hasn\'t saved any routes.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userRoutes.length,
      itemBuilder: (context, index) {
        final route = _userRoutes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildRouteCard(route),
        );
      },
    );
  }

  Widget _buildRouteCard(UserRoute route) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _calculateRouteCenter(route),
                  initialZoom: _calculateZoomLevel(route),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.runwithme_app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route.points.isNotEmpty
                            ? route.points
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList()
                            : [
                                LatLng(
                                  route.startPointLat,
                                  route.startPointLon,
                                ),
                                LatLng(route.endPointLat, route.endPointLon),
                              ],
                        strokeWidth: 4.0,
                        color: const Color(0xFF7ED321),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(route.startPointLat, route.startPointLon),
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      Marker(
                        point: LatLng(route.endPointLat, route.endPointLon),
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Route details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.title ?? 'Untitled Route',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (route.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              route.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (route.difficulty != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(route.difficulty!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          route.difficulty!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Time ago
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getTimeAgo(route.createdAt),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRouteStatColumn(
                      icon: Icons.straighten,
                      value: route.formattedDistance,
                      label: 'Distance',
                    ),
                    _buildRouteStatColumn(
                      icon: Icons.timer,
                      value: route.formattedDuration,
                      label: 'Duration',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
      case 'moderate':
        return Colors.orange;
      case 'hard':
      case 'difficult':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  LatLng _calculateRouteCenter(UserRoute route) {
    if (route.points.isEmpty) {
      return LatLng(
        (route.startPointLat + route.endPointLat) / 2,
        (route.startPointLon + route.endPointLon) / 2,
      );
    }

    double minLat = route.points.first.latitude;
    double maxLat = route.points.first.latitude;
    double minLon = route.points.first.longitude;
    double maxLon = route.points.first.longitude;

    for (var point in route.points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }

  double _calculateZoomLevel(UserRoute route) {
    if (route.points.isEmpty) {
      final latDiff = (route.startPointLat - route.endPointLat).abs();
      final lonDiff = (route.startPointLon - route.endPointLon).abs();
      final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

      if (maxDiff < 0.005) return 16.0;
      if (maxDiff < 0.01) return 15.0;
      if (maxDiff < 0.02) return 14.0;
      if (maxDiff < 0.05) return 13.0;
      if (maxDiff < 0.1) return 12.0;
      if (maxDiff < 0.2) return 11.0;
      return 10.0;
    }

    double minLat = route.points.first.latitude;
    double maxLat = route.points.first.latitude;
    double minLon = route.points.first.longitude;
    double maxLon = route.points.first.longitude;

    for (var point in route.points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final latDiff = maxLat - minLat;
    final lonDiff = maxLon - minLon;
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    if (maxDiff < 0.005) return 15.0;
    if (maxDiff < 0.01) return 14.0;
    if (maxDiff < 0.02) return 13.0;
    if (maxDiff < 0.05) return 12.0;
    if (maxDiff < 0.1) return 11.0;
    if (maxDiff < 0.2) return 10.0;
    return 9.0;
  }

  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article,
        title: 'No Posts Yet',
        subtitle: 'This user hasn\'t shared any posts.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        // Populate author info from the profile we're viewing
        final postWithAuthor = post.copyWith(
          authorUsername: _userProfile?.username ?? _userProfile?.displayName,
          authorFirstName: _userProfile?.firstName,
          authorLastName: _userProfile?.lastName,
          authorProfilePic: _userProfile?.profilePic,
        );
        return FeedPostCard(
          post: postWithAuthor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PostDetailScreen(postId: post.id, initialPost: postWithAuthor),
            ),
          ),
          onLike: () {},
          onComment: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PostDetailScreen(postId: post.id, initialPost: postWithAuthor),
            ),
          ),
          onAuthorTap: () {},
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

/// Delegate for pinned tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
