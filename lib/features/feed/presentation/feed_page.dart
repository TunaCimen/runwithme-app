import 'package:flutter/material.dart';
import 'matches_tab.dart';
import '../../auth/data/auth_service.dart';
import '../providers/feed_provider.dart';
import '../data/models/feed_post_dto.dart';
import '../../chat/presentation/screens/conversations_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/post_detail_screen.dart';
import 'widgets/feed_post_card.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FeedProvider _feedProvider;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _feedProvider = FeedProvider();

    final token = _authService.accessToken;
    if (token != null) {
      _feedProvider.setAuthToken(token);
      _feedProvider.loadFeed(refresh: true);
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
          IconButton(
            icon: const Icon(Icons.send_outlined, color: Colors.black87),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ConversationsScreen()),
            ),
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
                decoration: InputDecoration(
                  hintText: 'Search runners or routes...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
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
                _buildMatchesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    return ListenableBuilder(
      listenable: _feedProvider,
      builder: (context, _) {
        if (_feedProvider.feedLoading && _feedProvider.feedPosts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_feedProvider.feedError != null && _feedProvider.feedPosts.isEmpty) {
          return _buildErrorState();
        }

        if (_feedProvider.feedPosts.isEmpty) {
          return _buildEmptyFeedState();
        }

        return RefreshIndicator(
          onRefresh: () => _feedProvider.loadFeed(refresh: true),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _feedProvider.feedPosts.length +
                (_feedProvider.feedHasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _feedProvider.feedPosts.length) {
                _feedProvider.loadMoreFeed();
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final post = _feedProvider.feedPosts[index];
              return FeedPostCard(
                post: post,
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
              ),
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
        builder: (context) => PostDetailScreen(
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
  }

  void _navigateToProfile(String userId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to profile: $userId')),
    );
  }

  Widget _buildEmptyFeedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Colors.grey[300],
            ),
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to map or search
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Find runners feature coming soon!')),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Find Runners'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED321),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  Widget _buildMatchesTab() {
    return const MatchesTab();
  }
}
