import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/run_session.dart';
import '../../data/run_naming_service.dart';

/// A card widget that displays a run session with map preview and stats
/// Similar to route cards in the matches page
class RunSessionCard extends StatefulWidget {
  final RunSession session;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  /// Optional pre-computed name to avoid re-fetching
  final String? precomputedName;

  const RunSessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = false,
    this.precomputedName,
  });

  @override
  State<RunSessionCard> createState() => _RunSessionCardState();
}

class _RunSessionCardState extends State<RunSessionCard> {
  String? _runName;
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _loadRunName();
  }

  @override
  void didUpdateWidget(RunSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      _loadRunName();
    }
  }

  Future<void> _loadRunName() async {
    // Use precomputed name if available
    if (widget.precomputedName != null) {
      setState(() {
        _runName = widget.precomputedName;
        _isLoadingName = false;
      });
      return;
    }

    // Get start and end points from session
    LatLng? startPoint;
    LatLng? endPoint;

    if (widget.session.points.isNotEmpty) {
      final firstPoint = widget.session.points.first;
      final lastPoint = widget.session.points.last;
      startPoint = LatLng(firstPoint.latitude, firstPoint.longitude);
      endPoint = LatLng(lastPoint.latitude, lastPoint.longitude);
    }

    try {
      final name = await RunNamingService.generateRunName(
        startTime: widget.session.startedAt,
        startPoint: startPoint,
        endPoint: endPoint,
      );

      if (mounted) {
        setState(() {
          _runName = name;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _runName = _getSimpleRunTitle();
          _isLoadingName = false;
        });
      }
    }
  }

  String _getSimpleRunTitle() {
    final hour = widget.session.startedAt.hour;
    if (hour >= 5 && hour < 12) {
      return 'Morning Run';
    } else if (hour >= 12 && hour < 17) {
      return 'Afternoon Run';
    } else if (hour >= 17 && hour < 21) {
      return 'Evening Run';
    } else {
      return 'Night Run';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 180,
                child: widget.session.points.length > 1
                    ? _buildMapPreview()
                    : _buildNoTrackPlaceholder(),
              ),
            ),

            // Run details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and date
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isLoadingName
                                ? Row(
                                    children: [
                                      Text(
                                        _getSimpleRunTitle(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF7ED321),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _runName ?? _getSimpleRunTitle(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(widget.session.startedAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getTimeAgo(widget.session.startedAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.showDeleteButton)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: widget.onDelete,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        icon: Icons.straighten,
                        value: widget.session.formattedDistance,
                        label: 'Distance',
                      ),
                      _buildStatColumn(
                        icon: Icons.timer,
                        value: widget.session.formattedDurationCompact,
                        label: 'Duration',
                      ),
                      _buildStatColumn(
                        icon: Icons.speed,
                        value: widget.session.formattedPace,
                        label: 'Pace',
                      ),
                    ],
                  ),

                  // Public badge if applicable
                  if (widget.session.isPublic)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7ED321).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public,
                              size: 14,
                              color: Color(0xFF7ED321),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Public',
                              style: TextStyle(
                                color: Color(0xFF7ED321),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildMapPreview() {
    final points = widget.session.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    return FlutterMap(
      options: MapOptions(
        initialCenter: _calculateCenter(points),
        initialZoom: _calculateZoomLevel(points),
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
                child: const Icon(Icons.stop, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoTrackPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No track data', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final runDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (runDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (runDate == yesterday) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
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

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(0, 0);
    }

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

  double _calculateZoomLevel(List<LatLng> points) {
    if (points.isEmpty) return 15.0;

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
