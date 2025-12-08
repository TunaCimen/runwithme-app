import 'package:flutter/material.dart';
import '../../data/models/feed_post_dto.dart';

/// Card widget for displaying a feed post
class FeedPostCard extends StatelessWidget {
  final FeedPostDto post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;

  const FeedPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onAuthorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (post.textContent != null && post.textContent!.isNotEmpty)
              _buildContent(),
            if (post.postType == PostType.run || post.postType == PostType.route)
              _buildRoutePreview(),
            if (post.postType == PostType.photo && post.mediaUrl != null)
              _buildPhoto(),
            if (post.postType == PostType.run || post.postType == PostType.route)
              _buildStats(),
            _buildDivider(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
              backgroundImage: post.authorProfilePic != null
                  ? NetworkImage(post.authorProfilePic!)
                  : null,
              child: post.authorProfilePic == null
                  ? Text(
                      post.authorDisplayName.isNotEmpty
                          ? post.authorDisplayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF7ED321),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onAuthorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        post.authorDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPostTypeBadge(),
                    ],
                  ),
                  Text(
                    post.timeAgo,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildVisibilityIcon(),
        ],
      ),
    );
  }

  Widget _buildPostTypeBadge() {
    IconData icon;
    Color color;
    String label;

    switch (post.postType) {
      case PostType.run:
        icon = Icons.directions_run;
        color = Colors.orange;
        label = 'Run';
        break;
      case PostType.route:
        icon = Icons.map;
        color = Colors.blue;
        label = 'Route';
        break;
      case PostType.photo:
        icon = Icons.photo_camera;
        color = Colors.purple;
        label = 'Photo';
        break;
      case PostType.text:
        icon = Icons.chat_bubble_outline;
        color = Colors.grey;
        label = 'Post';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityIcon() {
    IconData icon;
    switch (post.visibility) {
      case PostVisibility.public:
        icon = Icons.public;
        break;
      case PostVisibility.friends:
        icon = Icons.people;
        break;
      case PostVisibility.private_:
        icon = Icons.lock;
        break;
    }
    return Icon(icon, size: 16, color: Colors.grey[400]);
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        post.textContent!,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildRoutePreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _RoutePathPainter(),
            ),
            const Positioned(
              left: 16,
              bottom: 16,
              child: _RouteBadge(label: 'Start', color: Color(0xFF2196F3)),
            ),
            const Positioned(
              right: 16,
              top: 16,
              child: _RouteBadge(label: 'Finish', color: Color(0xFFFF4444)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          post.mediaUrl!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStats() {
    if (post.formattedDistance.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (post.formattedDistance.isNotEmpty)
            _buildStatItem('${post.formattedDistance} km', 'Distance'),
          if (post.formattedPace.isNotEmpty)
            _buildStatItem('${post.formattedPace}/km', 'Pace'),
          if (post.formattedDuration.isNotEmpty)
            _buildStatItem(post.formattedDuration, 'Duration'),
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

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Divider(color: Colors.grey[200], height: 1),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _buildActionButton(
            icon: post.isLikedByCurrentUser
                ? Icons.favorite
                : Icons.favorite_border,
            label: '${post.likesCount}',
            color: post.isLikedByCurrentUser ? Colors.red : Colors.grey[700]!,
            onTap: onLike,
          ),
          _buildActionButton(
            icon: Icons.comment_outlined,
            label: '${post.commentsCount}',
            color: Colors.grey[700]!,
            onTap: onComment,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.share_outlined, color: Colors.grey[700]),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
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

class _RouteBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RouteBadge({required this.label, required this.color});

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

class _RoutePathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7ED321)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
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

    final startPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.75),
      6,
      startPaint,
    );

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
