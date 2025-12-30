import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/utils/profile_pic_helper.dart';
import '../../../../core/widgets/highlighted_text.dart';
import '../../data/models/feed_post_dto.dart';

/// Card widget for displaying a feed post
class FeedPostCard extends StatelessWidget {
  final FeedPostDto post;
  final String? searchQuery;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onAuthorTap;

  const FeedPostCard({
    super.key,
    required this.post,
    this.searchQuery,
    this.onTap,
    this.onLike,
    this.onComment,
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
            // Show run/route title
            if (post.postType == PostType.run ||
                post.postType == PostType.route)
              _buildRunTitle(),
            // Show route preview for run/route type posts
            if (post.postType == PostType.run ||
                post.postType == PostType.route)
              _buildRoutePreview(),
            // Show photo if mediaUrl is present (for any post type)
            if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
              _buildPhoto(context),
            // Show stats for run/route type posts
            if (post.postType == PostType.run ||
                post.postType == PostType.route)
              _buildStats(),
            _buildDivider(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final profilePicUrl = ProfilePicHelper.getProfilePicUrl(
      post.authorProfilePic,
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
              backgroundImage: profilePicUrl != null
                  ? NetworkImage(profilePicUrl)
                  : null,
              child: profilePicUrl == null
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
                      Flexible(
                        child: HighlightedText(
                          text: post.authorDisplayName,
                          searchQuery: searchQuery,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPostTypeBadge(),
                    ],
                  ),
                  Text(
                    post.timeAgo,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
      case PostType.text:
        // Text posts with media show as photo, otherwise as post
        if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
          icon = Icons.photo_camera;
          color = Colors.purple;
          label = 'Photo';
        } else {
          icon = Icons.chat_bubble_outline;
          color = Colors.grey;
          label = 'Post';
        }
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
      child: HighlightedText(
        text: post.textContent!,
        searchQuery: searchQuery,
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
    );
  }

  Widget _buildRunTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            post.postType == PostType.run ? Icons.directions_run : Icons.route,
            size: 18,
            color: const Color(0xFF7ED321),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: HighlightedText(
              text: post.displayTitle,
              searchQuery: searchQuery,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePreview() {
    // Check if we have route points to display
    final hasPoints = post.routePoints != null && post.routePoints!.length > 1;
    final hasCoordinates =
        post.startPointLat != null && post.startPointLon != null;

    if (!hasPoints && !hasCoordinates) {
      // Show placeholder if no coordinates available
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

    // Build list of points for the polyline
    List<LatLng> points = [];
    if (hasPoints) {
      points = post.routePoints!
          .map((p) => LatLng(p['latitude']!, p['longitude']!))
          .toList();
    } else if (hasCoordinates) {
      points = [
        LatLng(post.startPointLat!, post.startPointLon!),
        if (post.endPointLat != null && post.endPointLon != null)
          LatLng(post.endPointLat!, post.endPointLon!),
      ];
    }

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate center and zoom
    final center = _calculateCenter(points);
    final zoom = _calculateZoom(points);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 160,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.runwithme_app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.0,
                    color: const Color(0xFF7ED321),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Start marker
                  Marker(
                    point: points.first,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  // End marker
                  if (points.length > 1)
                    Marker(
                      point: points.last,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
    );
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points.first;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }

  double _calculateZoom(List<LatLng> points) {
    if (points.isEmpty || points.length == 1) return 15.0;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
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

  Widget _buildPhoto(BuildContext context) {
    final imageUrl = post.getFullMediaUrl();
    if (imageUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => _showFullScreenImage(context, imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    color: const Color(0xFF7ED321),
                  ),
                ),
              );
            },
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
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullScreenImageView(imageUrl: imageUrl),
          );
        },
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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

    final path = ui.Path();
    path.moveTo(size.width * 0.15, size.height * 0.75);
    path.cubicTo(
      size.width * 0.3,
      size.height * 0.6,
      size.width * 0.4,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.45,
    );
    path.cubicTo(
      size.width * 0.6,
      size.height * 0.4,
      size.width * 0.7,
      size.height * 0.3,
      size.width * 0.85,
      size.height * 0.25,
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

/// Full screen image viewer with pinch-to-zoom
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Full screen interactive image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: const Color(0xFF7ED321),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
