import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../auth/data/auth_service.dart';
import '../data/location_tracking_service.dart';

/// Live tracking page for recording running sessions with background support
class LiveTrackingPage extends StatefulWidget {
  final int? routeId;

  const LiveTrackingPage({super.key, this.routeId});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final AuthService _authService = AuthService();
  final LocationTrackingService _trackingService = LocationTrackingService();

  // UI state
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isStopping = false;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
    _setupCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't dispose the tracking service - it should continue in background
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes for background tracking
    if (state == AppLifecycleState.resumed && _trackingService.isTracking) {
      // App came back to foreground, refresh UI
      setState(() {});
    }
  }

  void _setupCallbacks() {
    _trackingService.onLocationUpdate = (position, speed) {
      if (mounted) {
        setState(() {
          _currentLocation = position;
        });
        // Keep map centered on current location
        _mapController.move(position, _mapController.camera.zoom);
      }
    };

    _trackingService.onTimerUpdate = (seconds) {
      if (mounted) {
        setState(() {});
      }
    };

    _trackingService.onDistanceUpdate = (distance) {
      if (mounted) {
        setState(() {});
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

  Future<void> _initializeTracking() async {
    setState(() {
      _isLoading = true;
    });

    final initialized = await _trackingService.initialize();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enable location services and grant permissions',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Get initial position
    final position = await _trackingService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = position;
        _isLoading = false;
      });
      if (position != null) {
        _mapController.move(position, 16.0);
      }
    }
  }

  Future<void> _startTracking() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS signal...')),
      );
      return;
    }

    final accessToken = _authService.accessToken;
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to track runs')),
      );
      return;
    }

    // Request background permission on Android
    final hasBackgroundPermission = await _trackingService
        .requestBackgroundPermission();
    if (!hasBackgroundPermission) {
      if (mounted) {
        final proceed = await _showBackgroundPermissionDialog();
        if (!proceed) return;
      }
    }

    setState(() {
      _isStarting = true;
    });

    final started = await _trackingService.startTracking(
      accessToken: accessToken,
      routeId: widget.routeId,
      isPublic: false,
      useBackgroundTracking: hasBackgroundPermission,
    );

    setState(() {
      _isStarting = false;
    });

    if (!started && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to start tracking')));
    }
  }

  Future<bool> _showBackgroundPermissionDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Background Location'),
            content: const Text(
              'For best tracking results, allow location access "Always" in your device settings. '
              'Without this, tracking may stop when the app is in the background.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _pauseTracking() {
    _trackingService.pauseTracking();
    setState(() {});
  }

  void _resumeTracking() {
    _trackingService.resumeTracking();
    setState(() {});
  }

  Future<void> _stopTracking() async {
    if (_trackingService.trackPoints.length <= 1) {
      await _trackingService.discardTracking();
      setState(() {});
      return;
    }

    _showSaveDialog();
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Run Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Distance', _trackingService.formattedDistance),
            _buildStatRow('Duration', _trackingService.formattedDuration),
            _buildStatRow('Avg Pace', _trackingService.formattedPace),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _discardRun();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveRun();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7ED321),
            ),
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
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _discardRun() async {
    await _trackingService.discardTracking();
    setState(() {});
  }

  Future<void> _saveRun() async {
    setState(() {
      _isStopping = true;
    });

    final session = await _trackingService.stopTracking(save: true);

    setState(() {
      _isStopping = false;
    });

    if (mounted) {
      if (session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run saved successfully!')),
        );
        // Return the saved run session to the previous screen
        Navigator.pop(context, session);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save run')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = _trackingService.isTracking;
    final isPaused = _trackingService.isPaused;
    final trackPoints = _trackingService.trackPoints;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _currentLocation ?? const LatLng(41.085706, 29.001534),
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.runwithme_app',
              ),

              // Track polyline
              if (trackPoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trackPoints,
                      strokeWidth: 5.0,
                      color: const Color(0xFF7ED321),
                    ),
                  ],
                ),

              // Current location marker
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isTracking && !isPaused
                              ? const Color(0xFF7ED321)
                              : Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isTracking && !isPaused
                                          ? const Color(0xFF7ED321)
                                          : Colors.blue)
                                      .withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    // Start point marker
                    if (trackPoints.isNotEmpty && isTracking)
                      Marker(
                        point: trackPoints.first,
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
                  ],
                ),
            ],
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (isTracking) {
                    _showExitConfirmation();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),

          // Center on location button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: () {
                  if (_currentLocation != null) {
                    _mapController.move(_currentLocation!, 16.0);
                  }
                },
              ),
            ),
          ),

          // Stats panel
          if (isTracking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Duration (large)
                    Text(
                      _trackingService.formattedDuration,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Other stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Distance',
                          _trackingService.formattedDistance,
                        ),
                        _buildStatColumn(
                          'Pace',
                          _trackingService.formattedPace,
                        ),
                        _buildStatColumn(
                          'Speed',
                          _trackingService.formattedSpeed,
                        ),
                      ],
                    ),
                    if (isPaused)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'PAUSED',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Control buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isTracking) ...[
                  // Start button
                  GestureDetector(
                    onTap: (_isLoading || _isStarting) ? null : _startTracking,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7ED321),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF7ED321,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: _isStarting
                          ? const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                    ),
                  ),
                ] else ...[
                  // Pause/Resume button
                  GestureDetector(
                    onTap: isPaused ? _resumeTracking : _pauseTracking,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Stop button
                  GestureDetector(
                    onTap: _isStopping ? null : _stopTracking,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: _isStopping
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 32,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Run?'),
        content: const Text(
          'Are you sure you want to exit? Your current run will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(dialogContext); // Close dialog
              await _discardRun(); // Discard and delete from server
              if (mounted) {
                navigator.pop(); // Go back
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
