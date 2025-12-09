import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/route.dart' as route_model;
import '../../../core/models/user_profile.dart';
import '../../../core/utils/profile_pic_helper.dart';
import '../../auth/data/auth_service.dart';
import '../../map/data/route_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/user_profile_page.dart';

typedef RunRoute = route_model.Route;

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final RouteRepository _routeRepository = RouteRepository();
  final AuthService _authService = AuthService();
  final ProfileRepository _profileRepository = ProfileRepository();

  List<RunRoute> _publicRoutes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Like state
  final Map<int, bool> _likedRoutes = {};
  final Map<int, int> _likeCounts = {};

  // Creator profiles cache
  final Map<String, UserProfile> _creatorProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadPublicRoutes();
  }

  /// Load public routes
  /// Set [forceRefresh] to true to bypass cache (e.g., on pull-to-refresh)
  Future<void> _loadPublicRoutes({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // If forcing refresh, clear the caches first
    if (forceRefresh) {
      _routeRepository.clearCache();
      _profileRepository.clearCache();
    }

    final result = await _routeRepository.getPublicRoutes(
      page: 0,
      size: 50,
      accessToken: _authService.accessToken,
      forceRefresh: forceRefresh,
    );

    if (result.success && result.routes != null) {
      // Fetch full route details to get all points for proper visualization
      final fullRoutes = await _routeRepository.fetchFullRouteDetails(
        routes: result.routes!,
        accessToken: _authService.accessToken,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          // Sort by created date (newest first)
          _publicRoutes = fullRoutes;
          _publicRoutes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });

        // Load like status and creator profiles for each route in parallel
        _loadAllLikeStatuses(_publicRoutes, forceRefresh: forceRefresh);
        _loadAllCreatorProfiles(_publicRoutes, forceRefresh: forceRefresh);
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = result.message ?? 'Failed to load routes';
        });
      }
    }
  }

  /// Load all like statuses in parallel (batched)
  Future<void> _loadAllLikeStatuses(List<RunRoute> routes, {bool forceRefresh = false}) async {
    if (_authService.accessToken == null) return;

    final stopwatch = Stopwatch()..start();
    const batchSize = 10;

    for (var i = 0; i < routes.length; i += batchSize) {
      final batchEnd = (i + batchSize < routes.length) ? i + batchSize : routes.length;
      final batch = routes.sublist(i, batchEnd);

      await Future.wait(
        batch.map((route) => _loadLikeStatus(route.id, forceRefresh: forceRefresh)),
      );
    }

    stopwatch.stop();
    debugPrint('[MatchesTab] Loaded like statuses for ${routes.length} routes in ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Load all creator profiles in parallel (batched)
  Future<void> _loadAllCreatorProfiles(List<RunRoute> routes, {bool forceRefresh = false}) async {
    final stopwatch = Stopwatch()..start();

    // Get unique creator IDs that haven't been loaded yet (unless forcing refresh)
    final creatorIds = routes
        .where((r) => r.creatorId != null && (forceRefresh || !_creatorProfiles.containsKey(r.creatorId)))
        .map((r) => r.creatorId!)
        .toSet()
        .toList();

    if (creatorIds.isEmpty) return;

    const batchSize = 10;

    for (var i = 0; i < creatorIds.length; i += batchSize) {
      final batchEnd = (i + batchSize < creatorIds.length) ? i + batchSize : creatorIds.length;
      final batch = creatorIds.sublist(i, batchEnd);

      await Future.wait(
        batch.map((creatorId) => _loadCreatorProfile(creatorId, forceRefresh: forceRefresh)),
      );
    }

    stopwatch.stop();
    debugPrint('[MatchesTab] Loaded ${creatorIds.length} creator profiles in ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Load like status and count for a route
  Future<void> _loadLikeStatus(int routeId, {bool forceRefresh = false}) async {
    if (_authService.accessToken == null) return;

    try {
      // Run both calls in parallel
      final results = await Future.wait([
        _routeRepository.checkIfLiked(
          routeId: routeId,
          accessToken: _authService.accessToken!,
          forceRefresh: forceRefresh,
        ),
        _routeRepository.getLikeCount(
          routeId: routeId,
          accessToken: _authService.accessToken,
          forceRefresh: forceRefresh,
        ),
      ]);

      final isLiked = results[0] as bool;
      final count = results[1] as int;

      if (mounted) {
        setState(() {
          _likedRoutes[routeId] = isLiked;
          _likeCounts[routeId] = count;
        });
      }
    } catch (e) {
      // Silently fail - like status is not critical
    }
  }

  /// Load creator profile for a route
  Future<void> _loadCreatorProfile(String creatorId, {bool forceRefresh = false}) async {
    // Skip if already loaded (unless forcing refresh)
    if (!forceRefresh && _creatorProfiles.containsKey(creatorId)) return;

    final accessToken = _authService.accessToken;
    if (accessToken == null) return;

    final result = await _profileRepository.getProfile(
      creatorId,
      accessToken: accessToken,
      forceRefresh: forceRefresh,
    );

    if (mounted && result.success && result.profile != null) {
      setState(() {
        _creatorProfiles[creatorId] = result.profile!;
      });
    }
  }

  /// Navigate to user profile
  void _navigateToUserProfile(String userId) {
    final profile = _creatorProfiles[userId];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          userId: userId,
          username: profile?.fullName,
        ),
      ),
    );
  }

  /// Toggle like status for a route
  Future<void> _toggleLike(RunRoute route) async {
    if (_authService.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like routes')),
      );
      return;
    }

    final isCurrentlyLiked = _likedRoutes[route.id] ?? false;
    final currentCount = _likeCounts[route.id] ?? 0;

    // Optimistic update
    setState(() {
      _likedRoutes[route.id] = !isCurrentlyLiked;
      _likeCounts[route.id] = isCurrentlyLiked ? currentCount - 1 : currentCount + 1;
    });

    try {
      if (isCurrentlyLiked) {
        await _routeRepository.unlikeRoute(
          routeId: route.id,
          accessToken: _authService.accessToken!,
        );
      } else {
        await _routeRepository.likeRoute(
          routeId: route.id,
          accessToken: _authService.accessToken!,
        );
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _likedRoutes[route.id] = isCurrentlyLiked;
          _likeCounts[route.id] = currentCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like')),
        );
      }
    }
  }

  Future<void> _joinRoute(RunRoute route) async {
    // TODO: Implement join route functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joining route: ${route.title ?? "Untitled Route"}'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to map with this route
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _loadPublicRoutes(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED321),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_publicRoutes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadPublicRoutes(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FCD9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7ED321).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discover Running Routes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore ${_publicRoutes.length} public routes shared by the community',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Route cards
          ..._publicRoutes.map((route) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildRouteCard(route),
              )),
        ],
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
            Icon(
              Icons.route,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'No Routes Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to share a public route with the community',
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

  Widget _buildRouteCard(RunRoute route) {
    final creatorProfile = route.creatorId != null
        ? _creatorProfiles[route.creatorId]
        : null;
    final currentUserId = _authService.currentUser?.userId;
    final isOwnRoute = route.creatorId == currentUserId;

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
          // Creator header
          if (route.creatorId != null)
            InkWell(
              onTap: () => _navigateToUserProfile(route.creatorId!),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final profilePicUrl = ProfilePicHelper.getProfilePicUrl(creatorProfile?.profilePic);
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF7ED321),
                          backgroundImage: profilePicUrl != null
                              ? NetworkImage(profilePicUrl)
                              : null,
                          child: profilePicUrl == null
                              ? Text(
                                  _getCreatorInitial(creatorProfile),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _getCreatorName(creatorProfile, isOwnRoute),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOwnRoute) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7ED321).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Color(0xFF7ED321),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _getTimeAgo(route.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),

          // Map preview
          ClipRRect(
            borderRadius: route.creatorId != null
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _calculateRouteCenter(route),
                  initialZoom: _calculateZoomLevel(route),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // Disable interactions
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
                        // Use route points if available, otherwise draw line from start to end
                        points: route.points.isNotEmpty
                            ? route.points.map((p) => LatLng(p.latitude, p.longitude)).toList()
                            : [
                                LatLng(route.startPointLat, route.startPointLon),
                                LatLng(route.endPointLat, route.endPointLon),
                              ],
                        strokeWidth: 4.0,
                        color: const Color(0xFF7ED321),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Start marker
                      Marker(
                        point: LatLng(route.startPointLat, route.startPointLon),
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                        ),
                      ),
                      // End marker
                      Marker(
                        point: LatLng(route.endPointLat, route.endPointLon),
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stop, color: Colors.white, size: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                // Time ago and like button
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getTimeAgo(route.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    // Like button
                    GestureDetector(
                      onTap: () => _toggleLike(route),
                      child: Row(
                        children: [
                          Icon(
                            (_likedRoutes[route.id] ?? false)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: (_likedRoutes[route.id] ?? false)
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_likeCounts[route.id] ?? 0}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      icon: Icons.straighten,
                      value: route.formattedDistance,
                      label: 'Distance',
                    ),
                    _buildStatColumn(
                      icon: Icons.timer,
                      value: route.formattedDuration,
                      label: 'Duration',
                    ),
                    _buildStatColumn(
                      icon: Icons.route,
                      value: '${route.points.length}',
                      label: 'Points',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Join button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _joinRoute(route),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7ED321),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_run),
                        SizedBox(width: 8),
                        Text(
                          'Join This Route',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCreatorInitial(UserProfile? profile) {
    if (profile != null && profile.fullName.isNotEmpty) {
      return profile.fullName[0].toUpperCase();
    }
    return '?';
  }

  String _getCreatorName(UserProfile? profile, bool isOwnRoute) {
    if (isOwnRoute) {
      if (profile != null && profile.fullName.isNotEmpty) {
        return profile.fullName;
      }
      return _authService.currentUser?.username ?? 'You';
    }
    if (profile != null && profile.fullName.isNotEmpty) {
      return profile.fullName;
    }
    return 'Runner';
  }

  Widget _buildStatColumn({
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
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'very hard':
        return Colors.purple;
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

  /// Calculate the center point of a route to show both start and end
  LatLng _calculateRouteCenter(RunRoute route) {
    if (route.points.isEmpty) {
      // Fallback to midpoint between start and end
      return LatLng(
        (route.startPointLat + route.endPointLat) / 2,
        (route.startPointLon + route.endPointLon) / 2,
      );
    }

    // Calculate center from all points
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

  /// Calculate appropriate zoom level to fit the entire route
  double _calculateZoomLevel(RunRoute route) {
    if (route.points.isEmpty) {
      // Calculate from start/end points
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

    // Calculate from all points
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

    // Add padding by using slightly lower zoom
    if (maxDiff < 0.005) return 15.0;
    if (maxDiff < 0.01) return 14.0;
    if (maxDiff < 0.02) return 13.0;
    if (maxDiff < 0.05) return 12.0;
    if (maxDiff < 0.1) return 11.0;
    if (maxDiff < 0.2) return 10.0;
    return 9.0;
  }
}
