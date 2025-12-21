import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/models/route.dart' as route_model;
import '../../auth/data/auth_service.dart';
import '../../run/data/location_tracking_service.dart';

typedef RunRoute = route_model.Route;

/// Page for navigating a route with live tracking
class RouteNavigationPage extends StatefulWidget {
  final RunRoute route;

  const RouteNavigationPage({super.key, required this.route});

  @override
  State<RouteNavigationPage> createState() => _RouteNavigationPageState();
}

class _RouteNavigationPageState extends State<RouteNavigationPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationTrackingService _trackingService = LocationTrackingService();
  final AuthService _authService = AuthService();

  bool _isTracking = false;
  bool _isPaused = false;
  bool _isStarting = false;
  bool _hasStarted = false;

  // Current location
  LatLng? _currentLocation;

  // Route points for navigation
  List<LatLng> _routePoints = [];
  int _currentWaypointIndex = 0;

  // Tracking stats
  double _distanceCovered = 0;
  int _elapsedSeconds = 0;
  double _distanceRemaining = 0;
  int _estimatedTimeRemaining = 0; // in seconds

  // Re-routing
  bool _isOffRoute = false;
  bool _isRerouting = false;
  static const double _offRouteThreshold = 50.0; // meters

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeRoute();
    _setupTrackingCallbacks();
    _initializeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingService.onLocationUpdate = null;
    _trackingService.onTimerUpdate = null;
    _trackingService.onDistanceUpdate = null;
    _trackingService.onError = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep tracking in background
    if (state == AppLifecycleState.paused && _isTracking) {
      debugPrint(
        '[RouteNavigationPage] App paused, tracking continues in background',
      );
    } else if (state == AppLifecycleState.resumed && _isTracking) {
      debugPrint('[RouteNavigationPage] App resumed');
      // Update UI with latest stats
      setState(() {
        _distanceCovered = _trackingService.totalDistanceM;
        _elapsedSeconds = _trackingService.elapsedSeconds;
      });
    }
  }

  void _initializeRoute() {
    debugPrint('[RouteNavigation] Initializing route: ${widget.route.title}');
    debugPrint(
      '[RouteNavigation] Route distance: ${widget.route.distanceM}m, duration: ${widget.route.estimatedDurationS}s',
    );

    // Convert route points to LatLng list
    if (widget.route.points.isNotEmpty) {
      _routePoints = widget.route.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      debugPrint(
        '[RouteNavigation] Loaded ${_routePoints.length} route points',
      );
    } else {
      // Fallback to start/end points
      _routePoints = [
        LatLng(widget.route.startPointLat, widget.route.startPointLon),
        LatLng(widget.route.endPointLat, widget.route.endPointLon),
      ];
      debugPrint('[RouteNavigation] Using start/end points only');
    }

    _distanceRemaining = widget.route.distanceM;
    _estimatedTimeRemaining = widget.route.estimatedDurationS;
  }

  Future<void> _initializeLocation() async {
    final initialized = await _trackingService.initialize();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services to navigate'),
          ),
        );
      }
      return;
    }

    final location = await _trackingService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() {
        _currentLocation = location;
      });
      _mapController.move(location, 16.0);
    }
  }

  void _setupTrackingCallbacks() {
    _trackingService.onLocationUpdate = (location, speed) {
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _updateNavigationProgress();
        });

        // Center map on user (with slight offset toward destination)
        _mapController.move(location, _mapController.camera.zoom);
      }
    };

    _trackingService.onTimerUpdate = (seconds) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = seconds;
        });
      }
    };

    _trackingService.onDistanceUpdate = (distance) {
      if (mounted) {
        setState(() {
          _distanceCovered = distance;
          _distanceRemaining = (widget.route.distanceM - distance).clamp(
            0,
            double.infinity,
          );
        });
      }
    };

    _trackingService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    };
  }

  void _updateNavigationProgress() {
    if (_currentLocation == null || _routePoints.isEmpty) return;

    // Find closest point on route
    const distanceCalculator = Distance();
    double minDistance = double.infinity;
    int closestIndex = _currentWaypointIndex;

    for (int i = _currentWaypointIndex; i < _routePoints.length; i++) {
      final distance = distanceCalculator.as(
        LengthUnit.Meter,
        _currentLocation!,
        _routePoints[i],
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    debugPrint(
      '[RouteNavigation] Progress: waypoint $closestIndex/${_routePoints.length}, distance to route: ${minDistance.toStringAsFixed(1)}m',
    );

    // Check if user is off route
    final wasOffRoute = _isOffRoute;
    _isOffRoute = minDistance > _offRouteThreshold;

    if (_isOffRoute && !wasOffRoute && _hasStarted) {
      debugPrint(
        '[RouteNavigation] User is OFF ROUTE (${minDistance.toStringAsFixed(1)}m from route)',
      );
      _handleOffRoute();
    } else if (!_isOffRoute && wasOffRoute) {
      debugPrint('[RouteNavigation] User is back ON ROUTE');
    }

    // Update current waypoint
    if (closestIndex > _currentWaypointIndex) {
      setState(() {
        _currentWaypointIndex = closestIndex;
      });
    }

    // Calculate remaining distance along the route
    double remainingDistance = 0;
    for (int i = closestIndex; i < _routePoints.length - 1; i++) {
      remainingDistance += distanceCalculator.as(
        LengthUnit.Meter,
        _routePoints[i],
        _routePoints[i + 1],
      );
    }

    // Calculate estimated time remaining
    // Use average pace if available, otherwise use route's estimated duration
    int estimatedTimeRemaining = 0;
    if (_distanceCovered > 100 && _elapsedSeconds > 0) {
      // Calculate based on current pace
      final paceSecPerMeter = _elapsedSeconds / _distanceCovered;
      estimatedTimeRemaining = (remainingDistance * paceSecPerMeter).toInt();
    } else if (widget.route.distanceM > 0) {
      // Use route's estimated duration
      final routePaceSecPerMeter =
          widget.route.estimatedDurationS / widget.route.distanceM;
      estimatedTimeRemaining = (remainingDistance * routePaceSecPerMeter)
          .toInt();
    }

    setState(() {
      _distanceRemaining = remainingDistance;
      _estimatedTimeRemaining = estimatedTimeRemaining;
    });

    // Check if reached destination (within 30 meters)
    final distanceToEnd = distanceCalculator.as(
      LengthUnit.Meter,
      _currentLocation!,
      _routePoints.last,
    );

    if (distanceToEnd < 30 && _hasStarted) {
      _onReachedDestination();
    }
  }

  /// Handle when user goes off route - trigger re-routing
  void _handleOffRoute() {
    if (_isRerouting) return;

    // Show notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are off route. Recalculating...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Trigger re-routing
    _recalculateRoute();
  }

  /// Recalculate route from current location to destination
  Future<void> _recalculateRoute() async {
    if (_currentLocation == null || _isRerouting) return;

    setState(() {
      _isRerouting = true;
    });

    debugPrint(
      '[RouteNavigation] Recalculating route from current location...',
    );

    try {
      final destination = _routePoints.last;
      final coordinates =
          '${_currentLocation!.longitude},${_currentLocation!.latitude};${destination.longitude},${destination.latitude}';

      final url =
          'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
          '$coordinates'
          '?overview=full&geometries=geojson&steps=true';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RunWithMeApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final distance = route['distance'] as num;
          final duration = route['duration'] as num;

          // Convert to LatLng list
          final newRoutePoints = coordinates.map((coord) {
            final c = coord as List;
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();

          debugPrint(
            '[RouteNavigation] New route: ${newRoutePoints.length} points, ${distance}m, ${duration}s',
          );

          if (mounted) {
            setState(() {
              _routePoints = newRoutePoints;
              _currentWaypointIndex = 0;
              _distanceRemaining = distance.toDouble();
              _estimatedTimeRemaining = duration.toInt();
              _isOffRoute = false;
              _isRerouting = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Route recalculated!'),
                backgroundColor: Color(0xFF7ED321),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      debugPrint('[RouteNavigation] Failed to recalculate route');
      if (mounted) {
        setState(() {
          _isRerouting = false;
        });
      }
    } catch (e) {
      debugPrint('[RouteNavigation] Error recalculating route: $e');
      if (mounted) {
        setState(() {
          _isRerouting = false;
        });
      }
    }
  }

  Future<void> _startNavigation() async {
    if (_isStarting) return;

    setState(() {
      _isStarting = true;
    });

    final token = _authService.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to track your run')),
      );
      setState(() {
        _isStarting = false;
      });
      return;
    }

    final success = await _trackingService.startTracking(
      accessToken: token,
      routeId: widget.route.id,
      isPublic: false,
      useBackgroundTracking: true,
    );

    if (success) {
      setState(() {
        _isTracking = true;
        _isPaused = false;
        _hasStarted = true;
        _isStarting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation started! Follow the green route.'),
          ),
        );
      }
    } else {
      setState(() {
        _isStarting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start tracking')),
        );
      }
    }
  }

  void _togglePause() {
    if (_isPaused) {
      _trackingService.resumeTracking();
      setState(() {
        _isPaused = false;
      });
    } else {
      _trackingService.pauseTracking();
      setState(() {
        _isPaused = true;
      });
    }
  }

  Future<void> _stopNavigation({bool save = true}) async {
    final session = await _trackingService.stopTracking(save: save);

    if (mounted) {
      if (session != null && save) {
        Navigator.pop(context, session);
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _onReachedDestination() {
    if (!_isTracking) return;

    // Show congratulations dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Color(0xFF7ED321), size: 32),
            const SizedBox(width: 12),
            const Text('Congratulations!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You\'ve reached your destination!'),
            const SizedBox(height: 16),
            _buildStatRow('Distance', _formatDistance(_distanceCovered)),
            _buildStatRow('Duration', _formatDuration(_elapsedSeconds)),
            _buildStatRow(
              'Pace',
              _formatPace(_elapsedSeconds, _distanceCovered),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNavigation(save: true);
            },
            child: const Text('Save Run'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showStopConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Navigation?'),
        content: const Text('Do you want to save your progress?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNavigation(save: false);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNavigation(save: true);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7ED321),
            ),
            child: const Text('Save Run'),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toInt()} m';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    }
    return '${minutes}m ${secs}s';
  }

  String _formatPace(int seconds, double meters) {
    if (meters < 100) return '--:--/km';
    final paceSecondsPerKm = seconds / (meters / 1000);
    final paceMinutes = paceSecondsPerKm ~/ 60;
    final paceSeconds = (paceSecondsPerKm % 60).toInt();
    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}/km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _routePoints.isNotEmpty
                  ? _routePoints.first
                  : const LatLng(41.085706, 29.001534),
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.runwithme_app',
              ),

              // Route polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 6.0,
                    color: const Color(0xFF7ED321),
                  ),
                ],
              ),

              // User's tracked path
              if (_trackingService.trackPoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trackingService.trackPoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Start marker
                  if (_routePoints.isNotEmpty)
                    Marker(
                      point: _routePoints.first,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                  // End marker
                  if (_routePoints.length > 1)
                    Marker(
                      point: _routePoints.last,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                  // User location marker
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Back button and route info header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (_isTracking) {
                          _showStopConfirmation();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Route title
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        widget.route.title ?? 'Route Navigation',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats row
                  if (_hasStarted) ...[
                    // Off-route indicator
                    if (_isOffRoute || _isRerouting)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _isRerouting
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isRerouting ? Colors.orange : Colors.red,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isRerouting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              )
                            else
                              const Icon(
                                Icons.wrong_location,
                                color: Colors.red,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isRerouting
                                  ? 'Recalculating route...'
                                  : 'Off route',
                              style: TextStyle(
                                color: _isRerouting
                                    ? Colors.orange
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          _formatDistance(_distanceCovered),
                          'Covered',
                          Icons.straighten,
                        ),
                        _buildStatColumn(
                          _formatDuration(_elapsedSeconds),
                          'Duration',
                          Icons.timer,
                        ),
                        _buildStatColumn(
                          _formatDistance(_distanceRemaining),
                          'Remaining',
                          Icons.flag,
                        ),
                        _buildStatColumn(
                          _formatDuration(_estimatedTimeRemaining),
                          'ETA',
                          Icons.schedule,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    // Route info before starting
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          widget.route.formattedDistance,
                          'Distance',
                          Icons.straighten,
                        ),
                        _buildStatColumn(
                          widget.route.formattedDuration,
                          'Est. Time',
                          Icons.timer,
                        ),
                        _buildStatColumn(
                          widget.route.difficulty ?? 'N/A',
                          'Difficulty',
                          Icons.trending_up,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Control buttons
                  if (!_hasStarted)
                    // Start button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isStarting ? null : _startNavigation,
                        icon: _isStarting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isStarting ? 'Starting...' : 'Start Run'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7ED321),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    // Pause/Resume and Stop buttons
                    Row(
                      children: [
                        // Pause/Resume button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _togglePause,
                            icon: Icon(
                              _isPaused ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text(_isPaused ? 'Resume' : 'Pause'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Stop button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showStopConfirmation,
                            icon: const Icon(Icons.stop),
                            label: const Text('Finish'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Center on user button
          Positioned(
            right: 16,
            bottom: _hasStarted ? 200 : 180,
            child: FloatingActionButton.small(
              heroTag: 'center_on_user',
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, 16.0);
                }
              },
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF7ED321), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
