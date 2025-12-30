import 'package:flutter/material.dart';
import 'matches_tab.dart';
import '../../auth/data/auth_service.dart';
import '../providers/feed_provider.dart';
import '../data/models/feed_post_dto.dart';
import '../../chat/presentation/screens/conversations_screen.dart';
import '../../chat/providers/global_chat_provider.dart';
import '../../profile/presentation/user_profile_page.dart';
import '../../profile/data/profile_repository.dart';
import '../../friends/providers/friends_provider.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/widgets/user_search_card.dart';
import 'screens/create_post_screen.dart';
import 'screens/post_detail_screen.dart';
import 'widgets/feed_post_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FeedProvider _feedProvider;
  late FriendsProvider _friendsProvider;
  final _authService = AuthService();
  final _profileRepository = ProfileRepository();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // User search state
  List<UserProfile> _searchedUsers = [];
  bool _isSearchingUsers = false;
  final Map<String, UserFriendshipStatus> _friendshipStatuses = {};
  final Set<String> _loadingFriendRequests = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _feedProvider = FeedProvider();
    _friendsProvider = FriendsProvider();

    final token = _authService.accessToken;
    final currentUser = _authService.currentUser;
    if (token != null) {
      _feedProvider.setAuthToken(token);
      _feedProvider.loadFeed(refresh: true);

      // Initialize friends provider for user search
      _friendsProvider.setAuthToken(token);
      if (currentUser != null) {
        _friendsProvider.setCurrentUserId(currentUser.userId);
      }
      _friendsProvider.loadAll();

      // Initialize global chat provider for unread count
      GlobalChatProvider().initialize(token, userId: currentUser?.userId);
    }

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    setState(() {
      _searchQuery = newQuery;
    });

    // Search for users when query changes
    if (newQuery.isNotEmpty) {
      _searchUsers(newQuery);
    } else {
      setState(() {
        _searchedUsers = [];
      });
    }
  }

  /// Search for users by name or username
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearchingUsers = true);

    final accessToken = _authService.accessToken;
    final currentUserId = _authService.currentUser?.userId;
    if (accessToken == null) {
      setState(() => _isSearchingUsers = false);
      return;
    }

    try {
      // Get all profiles and filter locally
      final result = await _profileRepository.getAllProfiles(
        accessToken: accessToken,
        page: 0,
        size: 50,
      );

      if (result.success && result.profiles != null) {
        final lowerQuery = query.toLowerCase();
        final filteredUsers = result.profiles!.where((profile) {
          // Exclude current user
          if (profile.userId == currentUserId) return false;

          // Search in name
          final fullName = profile.fullName.toLowerCase();
          if (fullName.contains(lowerQuery)) return true;

          // Search in first name
          final firstName = profile.firstName?.toLowerCase() ?? '';
          if (firstName.contains(lowerQuery)) return true;

          // Search in last name
          final lastName = profile.lastName?.toLowerCase() ?? '';
          if (lastName.contains(lowerQuery)) return true;

          // Search in username
          final username = profile.username?.toLowerCase() ?? '';
          if (username.contains(lowerQuery)) return true;

          return false;
        }).toList();

        // Update friendship statuses
        for (final user in filteredUsers) {
          _friendshipStatuses[user.userId] = _getFriendshipStatus(user.userId);
        }

        if (mounted) {
          setState(() {
            _searchedUsers = filteredUsers;
            _isSearchingUsers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingUsers = false);
      }
    }
  }

  /// Get friendship status for a user
  UserFriendshipStatus _getFriendshipStatus(String userId) {
    if (_friendsProvider.isFriend(userId)) {
      return UserFriendshipStatus.friends;
    }
    if (_friendsProvider.hasPendingSentRequest(userId)) {
      return UserFriendshipStatus.pendingSent;
    }
    if (_friendsProvider.hasPendingReceivedRequest(userId)) {
      return UserFriendshipStatus.pendingReceived;
    }
    return UserFriendshipStatus.none;
  }

  /// Send friend request to a user
  Future<void> _sendFriendRequest(String userId) async {
    setState(() => _loadingFriendRequests.add(userId));

    final result = await _friendsProvider.sendRequest(receiverId: userId);

    if (mounted) {
      setState(() {
        _loadingFriendRequests.remove(userId);
        if (result.success) {
          _friendshipStatuses[userId] = UserFriendshipStatus.pendingSent;
        }
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Color(0xFF7ED321),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to send request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostScreen()),
        ),
        backgroundColor: const Color(0xFF7ED321),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'RunWithMe',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: globalChatProvider,
            builder: (context, _) {
              final unreadCount = globalChatProvider.totalUnreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.send_outlined, color: Colors.black87),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConversationsScreen(),
                      ),
                    ).then((_) {
                      // Refresh unread count when returning from conversations
                      globalChatProvider.fetchUnreadCount();
                    }),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7ED321),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users, posts, or routes...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Posts/Matches tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'Matches'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                MatchesTab(searchQuery: _searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filter posts based on search query
  List<FeedPostDto> _filterPosts(List<FeedPostDto> posts) {
    if (_searchQuery.isEmpty) return posts;

    final query = _searchQuery.toLowerCase();
    return posts.where((post) {
      // Search in author display name
      final authorName = post.authorDisplayName.toLowerCase();
      if (authorName.contains(query)) return true;

      // Search in post text content
      final textContent = post.textContent?.toLowerCase() ?? '';
      if (textContent.contains(query)) return true;

      // Search in route title
      final routeTitle = post.routeTitle?.toLowerCase() ?? '';
      if (routeTitle.contains(query)) return true;

      return false;
    }).toList();
  }

  Widget _buildPostsTab() {
    return ListenableBuilder(
      listenable: _feedProvider,
      builder: (context, _) {
        // Show loading indicator during initial load or refresh when no posts exist
        if ((_feedProvider.feedLoading || _feedProvider.feedRefreshing) &&
            _feedProvider.feedPosts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF7ED321)),
          );
        }

        if (_feedProvider.feedError != null &&
            _feedProvider.feedPosts.isEmpty) {
          return _buildErrorState();
        }

        if (_feedProvider.feedPosts.isEmpty) {
          return _buildEmptyFeedState();
        }

        // Filter posts based on search query
        final filteredPosts = _filterPosts(_feedProvider.feedPosts);

        if (filteredPosts.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoSearchResultsState();
        }

        return RefreshIndicator(
          onRefresh: () => _feedProvider.loadFeed(refresh: true),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                filteredPosts.length +
                (_feedProvider.feedHasMore && _searchQuery.isEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= filteredPosts.length) {
                _feedProvider.loadMoreFeed();
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final post = filteredPosts[index];
              return FeedPostCard(
                post: post,
                searchQuery: _searchQuery,
                onTap: () => _navigateToPostDetail(post),
                onLike: () => _feedProvider.toggleLike(post.id),
                onComment: () => _navigateToPostDetail(post),
                onAuthorTap: () => _navigateToProfile(post.authorId),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoSearchResultsState() {
    // If we have matching users, show them instead of "no results"
    if (_searchedUsers.isNotEmpty) {
      return _buildUserSearchResults();
    }

    // Show loading if still searching users
    if (_isSearchingUsers) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7ED321)),
      );
    }

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text(
                'No Results Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No posts or users match "$_searchQuery"',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Search'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7ED321),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSearchResults() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Users matching "$_searchQuery"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // User cards
        ..._searchedUsers.map((user) => UserSearchCard(
              profile: user,
              searchQuery: _searchQuery,
              friendshipStatus:
                  _friendshipStatuses[user.userId] ?? UserFriendshipStatus.none,
              isLoading: _loadingFriendRequests.contains(user.userId),
              onTap: () => _navigateToProfile(user.userId),
              onSendRequest: () => _sendFriendRequest(user.userId),
            )),
        // No posts note
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No posts match your search, but we found these users.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              _feedProvider.feedError ?? 'Failed to load feed',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _feedProvider.loadFeed(refresh: true),
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

  void _navigateToPostDetail(FeedPostDto post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(postId: post.id, initialPost: post),
      ),
    );
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfilePage(userId: userId)),
    );
  }

  Widget _buildEmptyFeedState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 24),
              const Text(
                'No Posts Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start following other runners or complete your first run to see posts in your feed',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to map or search
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Find runners feature coming soon!'),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Find Runners'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED321),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
