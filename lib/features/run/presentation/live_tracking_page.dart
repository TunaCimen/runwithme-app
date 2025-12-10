import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/run_session.dart';
import '../../auth/data/auth_service.dart';
import '../../run/data/run_repository.dart';

/// Live tracking page for recording running sessions
class LiveTrackingPage extends StatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  final MapController _mapController = MapController();
  final AuthService _authService = AuthService();
  final RunRepository _runRepository = RunRepository();

  // Tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isLoading = false;
  DateTime? _startTime;
  DateTime? _pauseStartTime;
  Duration _pausedDuration = Duration.zero;

  // Location data
  LatLng? _currentLocation;
  final List<LatLng> _trackPoints = [];
  StreamSubscription<Position>? _positionSubscription;

  // Stats
  double _totalDistanceM = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;
  double _currentSpeedMps = 0;

  // Track points for saving
  final List<RunPoint> _runPoints = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _stopTracking();
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission permanently denied. Please enable in settings.'),
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _mapController.move(_currentLocation!, 16.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  void _startTracking() {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS signal...')),
      );
      return;
    }

    setState(() {
      _isTracking = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _trackPoints.clear();
      _runPoints.clear();
      _totalDistanceM = 0;
      _elapsedSeconds = 0;
      _pausedDuration = Duration.zero;
    });

    // Add initial point
    _trackPoints.add(_currentLocation!);
    _addRunPoint(_currentLocation!, 0);

    // Start location updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      if (!_isTracking || _isPaused) return;

      final newPoint = LatLng(position.latitude, position.longitude);

      // Calculate distance from last point
      if (_trackPoints.isNotEmpty) {
        final lastPoint = _trackPoints.last;
        final distance = const Distance().as(
          LengthUnit.Meter,
          lastPoint,
          newPoint,
        );
        _totalDistanceM += distance;
      }

      setState(() {
        _currentLocation = newPoint;
        _trackPoints.add(newPoint);
        _currentSpeedMps = position.speed > 0 ? position.speed : 0;
      });

      _addRunPoint(newPoint, position.speed);

      // Keep map centered on current location
      _mapController.move(newPoint, _mapController.camera.zoom);
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
    });
  }

  void _resumeTracking() {
    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
    }
    setState(() {
      _isPaused = false;
      _pauseStartTime = null;
    });
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _timer?.cancel();

    if (_isTracking && _trackPoints.length > 1) {
      _showSaveDialog();
    } else {
      setState(() {
        _isTracking = false;
        _isPaused = false;
      });
    }
  }

  void _addRunPoint(LatLng point, double speed) {
    _runPoints.add(RunPoint(
      id: 0,
      runSessionId: 0,
      seqNo: _runPoints.length,
      latitude: point.latitude,
      longitude: point.longitude,
      speedMps: speed,
      timestamp: DateTime.now(),
    ));
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
            _buildStatRow('Distance', _formattedDistance),
            _buildStatRow('Duration', _formattedDuration),
            _buildStatRow('Avg Pace', _formattedPace),
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

  void _discardRun() {
    setState(() {
      _isTracking = false;
      _isPaused = false;
      _trackPoints.clear();
      _runPoints.clear();
      _totalDistanceM = 0;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _saveRun() async {
    setState(() {
      _isLoading = true;
    });

    // Calculate average pace
    final avgPaceSecPerKm = _totalDistanceM > 0
        ? (_elapsedSeconds / (_totalDistanceM / 1000))
        : 0.0;

    final runSession = RunSession(
      id: 0,
      runnerId: _authService.currentUser?.userId,
      startTime: _startTime!,
      endTime: DateTime.now(),
      distanceM: _totalDistanceM,
      durationS: _elapsedSeconds,
      avgPaceSecPerKm: avgPaceSecPerKm,
      trackPoints: _runPoints,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _runRepository.saveRunSession(
      runSession,
      _authService.accessToken,
    );

    setState(() {
      _isLoading = false;
      _isTracking = false;
      _isPaused = false;
    });

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run saved successfully!')),
        );
        // Return the saved run session to the previous screen
        Navigator.pop(context, result.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to save run')),
        );
      }
    }
  }

  String get _formattedDistance {
    final km = _totalDistanceM / 1000;
    if (km >= 1) {
      return '${km.toStringAsFixed(2)} km';
    }
    return '${_totalDistanceM.toInt()} m';
  }

  String get _formattedDuration {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _formattedPace {
    if (_totalDistanceM < 10) return '--:--/km';
    final paceSecPerKm = _elapsedSeconds / (_totalDistanceM / 1000);
    final minutes = paceSecPerKm ~/ 60;
    final seconds = (paceSecPerKm % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  String get _formattedSpeed {
    if (_currentSpeedMps < 0.5) return '0.0 km/h';
    final kmh = _currentSpeedMps * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
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
              initialCenter: _currentLocation ?? const LatLng(41.085706, 29.001534),
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
              if (_trackPoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trackPoints,
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
                          color: _isTracking && !_isPaused
                              ? const Color(0xFF7ED321)
                              : Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: (_isTracking && !_isPaused
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
                    if (_trackPoints.isNotEmpty && _isTracking)
                      Marker(
                        point: _trackPoints.first,
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
                  if (_isTracking) {
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
          if (_isTracking)
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
                      _formattedDuration,
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
                        _buildStatColumn('Distance', _formattedDistance),
                        _buildStatColumn('Pace', _formattedPace),
                        _buildStatColumn('Speed', _formattedSpeed),
                      ],
                    ),
                    if (_isPaused)
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
                if (!_isTracking) ...[
                  // Start button
                  GestureDetector(
                    onTap: _isLoading ? null : _startTracking,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7ED321),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7ED321).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ] else ...[
                  // Pause/Resume button
                  GestureDetector(
                    onTap: _isPaused ? _resumeTracking : _pauseTracking,
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
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Stop button
                  GestureDetector(
                    onTap: _stopTracking,
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
                      child: const Icon(
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
              child: const Center(
                child: CircularProgressIndicator(),
              ),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Run?'),
        content: const Text(
          'Are you sure you want to exit? Your current run will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _discardRun();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
