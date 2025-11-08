import 'package:flutter/material.dart';
import 'matches_tab.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<FeedPost> _posts = [
    FeedPost(
      username: 'sarahjohnson',
      fullName: 'Sarah Johnson',
      location: 'Central Park, NYC',
      timeAgo: '2h ago',
      description: 'Beautiful morning run! The weather was perfect and I beat my personal record 🎉',
      distance: 5.2,
      pace: '5\'32"',
      duration: '28:45',
      likes: 124,
      comments: 18,
      imageUrl: null,
    ),
    FeedPost(
      username: 'marcuschen',
      fullName: 'Marcus Chen',
      location: 'Golden Gate Park',
      timeAgo: '5h ago',
      description: 'Long run today preparing for the marathon.',
      distance: 15.8,
      pace: '6\'12"',
      duration: '1:38:24',
      likes: 89,
      comments: 12,
      imageUrl: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            onPressed: () {},
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
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return _buildPostCard(_posts[index]);
        },
      ),
    );
  }

  Widget _buildMatchesTab() {
    return const MatchesTab();
  }

  Future<void> _refreshFeed() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  Widget _buildPostCard(FeedPost post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
                  child: Text(
                    post.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF7ED321),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            post.location,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' • ${post.timeAgo}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Route visualization with start/finish badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Route path visualization
                  CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: RoutePathPainter(),
                  ),
                  // Start badge
                  const Positioned(
                    left: 16,
                    bottom: 16,
                    child: _RouteBadge(
                      label: 'Start',
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  // Finish badge
                  const Positioned(
                    right: 16,
                    top: 16,
                    child: _RouteBadge(
                      label: 'Finish',
                      color: Color(0xFFFF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('${post.distance} km', 'Distance'),
                _buildStatItem('${post.pace}/km', 'Pace'),
                _buildStatItem(post.duration, 'Duration'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Divider(color: Colors.grey[200], height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.favorite,
                  label: '${post.likes}',
                  color: Colors.red,
                  onTap: () {},
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: '${post.comments}',
                  color: Colors.grey[700]!,
                  onTap: () {},
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.share_outlined, color: Colors.grey[700]),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Route badge widget
class _RouteBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RouteBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Custom painter for route path
class RoutePathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7ED321)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Create a curved path from bottom-left to top-right
    path.moveTo(size.width * 0.15, size.height * 0.75);

    path.cubicTo(
      size.width * 0.3, size.height * 0.6,
      size.width * 0.4, size.height * 0.5,
      size.width * 0.5, size.height * 0.45,
    );

    path.cubicTo(
      size.width * 0.6, size.height * 0.4,
      size.width * 0.7, size.height * 0.3,
      size.width * 0.85, size.height * 0.25,
    );

    canvas.drawPath(path, paint);

    // Draw start point
    final startPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.75),
      6,
      startPaint,
    );

    // Draw end point
    final endPaint = Paint()
      ..color = const Color(0xFFFF4444)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.25),
      6,
      endPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Feed post model
class FeedPost {
  final String username;
  final String fullName;
  final String location;
  final String timeAgo;
  final String description;
  final double distance;
  final String pace;
  final String duration;
  final int likes;
  final int comments;
  final String? imageUrl;

  FeedPost({
    required this.username,
    required this.fullName,
    required this.location,
    required this.timeAgo,
    required this.description,
    required this.distance,
    required this.pace,
    required this.duration,
    required this.likes,
    required this.comments,
    this.imageUrl,
  });
}
