import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/run_session.dart';
import 'run_repository.dart';

/// Service for managing location tracking during run sessions
class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final RunRepository _runRepository = RunRepository();

  // Tracking state
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  bool _isPaused = false;
  int? _activeSessionId;
  String? _accessToken;

  // Track data
  final List<LatLng> _trackPoints = [];
  final List<RunPoint> _runPoints = [];
  DateTime? _startTime;
  DateTime? _pauseStartTime;
  Duration _pausedDuration = Duration.zero;
  double _totalDistanceM = 0;
  int _elapsedSeconds = 0;
  double _currentSpeedMps = 0;
  double _elevationGainM = 0;
  double? _lastElevation;

  // Timer for elapsed time
  Timer? _timer;

  // Batch upload settings
  final List<RunPoint> _pendingPoints = [];
  Timer? _uploadTimer;
  static const _uploadInterval = Duration(seconds: 30);
  static const _minPointsForUpload = 5;

  // Callbacks
  void Function(LatLng position, double speed)? onLocationUpdate;
  void Function(int seconds)? onTimerUpdate;
  void Function(double distanceM)? onDistanceUpdate;
  void Function(String error)? onError;

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  int? get activeSessionId => _activeSessionId;
  List<LatLng> get trackPoints => List.unmodifiable(_trackPoints);
  List<RunPoint> get runPoints => List.unmodifiable(_runPoints);
  double get totalDistanceM => _totalDistanceM;
  int get elapsedSeconds => _elapsedSeconds;
  double get currentSpeedMps => _currentSpeedMps;
  double get elevationGainM => _elevationGainM;
  DateTime? get startTime => _startTime;
  Duration get pausedDuration => _pausedDuration;

  /// Initialize the service and check for permissions
  Future<bool> initialize() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationTrackingService] Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationTrackingService] Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        '[LocationTrackingService] Location permission permanently denied',
      );
      return false;
    }

    return true;
  }

  /// Request background location permission (Android only)
  Future<bool> requestBackgroundPermission() async {
    // On Android 10+, we need to request background location separately
    if (defaultTargetPlatform == TargetPlatform.android) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse) {
        // Need to request always permission for background
        final result = await Geolocator.requestPermission();
        return result == LocationPermission.always;
      }
      return permission == LocationPermission.always;
    }
    return true;
  }

  /// Get current location
  Future<LatLng?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint(
        '[LocationTrackingService] Error getting current location: $e',
      );
      return null;
    }
  }

  /// Start a new tracking session
  Future<bool> startTracking({
    required String accessToken,
    int? routeId,
    bool isPublic = false,
    bool useBackgroundTracking = true,
  }) async {
    debugPrint(
      '[LocationTrackingService] ========== START TRACKING ==========',
    );
    debugPrint(
      '[LocationTrackingService] routeId: $routeId, isPublic: $isPublic, background: $useBackgroundTracking',
    );

    if (_isTracking) {
      debugPrint(
        '[LocationTrackingService] WARNING: Already tracking, returning false',
      );
      return false;
    }

    _accessToken = accessToken;

    // Start session on server
    debugPrint('[LocationTrackingService] Creating session on server...');
    final result = await _runRepository.startRunSession(
      accessToken: accessToken,
      routeId: routeId,
      isPublic: isPublic,
    );

    if (!result.success || result.data == null) {
      debugPrint(
        '[LocationTrackingService] ERROR: Failed to start session on server: ${result.message}',
      );
      // Continue with local tracking even if server fails
      _activeSessionId = null;
    } else {
      _activeSessionId = result.data!.id;
      debugPrint(
        '[LocationTrackingService] SUCCESS: Session created with ID: $_activeSessionId',
      );
    }

    // Reset tracking state
    _trackPoints.clear();
    _runPoints.clear();
    _pendingPoints.clear();
    _totalDistanceM = 0;
    _elapsedSeconds = 0;
    _elevationGainM = 0;
    _lastElevation = null;
    _pausedDuration = Duration.zero;
    _startTime = DateTime.now();
    _isTracking = true;
    _isPaused = false;

    debugPrint(
      '[LocationTrackingService] State reset. Start time: $_startTime',
    );

    // Get initial position
    debugPrint('[LocationTrackingService] Getting initial position...');
    final initialPosition = await getCurrentLocation();
    if (initialPosition != null) {
      debugPrint(
        '[LocationTrackingService] Initial position: (${initialPosition.latitude}, ${initialPosition.longitude})',
      );
      _trackPoints.add(initialPosition);
      _addRunPoint(initialPosition, 0, null);
    } else {
      debugPrint(
        '[LocationTrackingService] WARNING: Could not get initial position',
      );
    }

    // Start location stream with background support
    debugPrint('[LocationTrackingService] Starting location stream...');
    _startLocationStream(useBackgroundTracking);

    // Start timer
    debugPrint('[LocationTrackingService] Starting timer...');
    _startTimer();

    // Start batch upload timer
    debugPrint('[LocationTrackingService] Starting upload timer...');
    _startUploadTimer();

    debugPrint(
      '[LocationTrackingService] ========== TRACKING STARTED ==========',
    );
    return true;
  }

  void _startLocationStream(bool useBackgroundTracking) {
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: useBackgroundTracking
            ? const ForegroundNotificationConfig(
                notificationText:
                    'RunWithMe is tracking your run in the background',
                notificationTitle: 'Run Tracking Active',
                enableWakeLock: true,
              )
            : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: useBackgroundTracking,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _onLocationUpdate,
          onError: (error) {
            debugPrint(
              '[LocationTrackingService] Location stream error: $error',
            );
            onError?.call('Location error: $error');
          },
        );
  }

  void _onLocationUpdate(Position position) {
    if (!_isTracking || _isPaused) {
      debugPrint(
        '[LocationTrackingService] Location update ignored: tracking=$_isTracking, paused=$_isPaused',
      );
      return;
    }

    final newPoint = LatLng(position.latitude, position.longitude);
    debugPrint(
      '[LocationTrackingService] Raw GPS update: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}), accuracy=${position.accuracy.toStringAsFixed(1)}m',
    );

    // Calculate distance from last point
    if (_trackPoints.isNotEmpty) {
      final lastPoint = _trackPoints.last;
      final distance = const Distance().as(
        LengthUnit.Meter,
        lastPoint,
        newPoint,
      );

      debugPrint(
        '[LocationTrackingService] Distance from last point: ${distance.toStringAsFixed(1)}m',
      );

      // Only add point if distance is significant (> 2 meters)
      if (distance < 2) {
        debugPrint(
          '[LocationTrackingService] Point filtered out (< 2m movement)',
        );
        return;
      }

      _totalDistanceM += distance;
      onDistanceUpdate?.call(_totalDistanceM);
      debugPrint(
        '[LocationTrackingService] Point added! Total distance now: ${_totalDistanceM.toStringAsFixed(1)}m',
      );
    } else {
      debugPrint('[LocationTrackingService] First point after initial');
    }

    // Track elevation gain
    if (position.altitude > 0) {
      if (_lastElevation != null) {
        final elevChange = position.altitude - _lastElevation!;
        if (elevChange > 0) {
          _elevationGainM += elevChange;
        }
      }
      _lastElevation = position.altitude;
    }

    _trackPoints.add(newPoint);
    _currentSpeedMps = position.speed > 0 ? position.speed : 0;

    // Add run point
    _addRunPoint(newPoint, position.speed, position.altitude);

    // Notify callback
    onLocationUpdate?.call(newPoint, _currentSpeedMps);
  }

  void _addRunPoint(LatLng point, double speed, double? elevation) {
    final runPoint = RunPoint(
      id: 0,
      runSessionId: _activeSessionId ?? 0,
      seqNo: _runPoints.length,
      latitude: point.latitude,
      longitude: point.longitude,
      elevationM: elevation,
      speedMps: speed > 0 ? speed : null,
      timestamp: DateTime.now(),
    );
    _runPoints.add(runPoint);
    _pendingPoints.add(runPoint);
  }

  void _startTimer() {
    _timer?.cancel();
    debugPrint(
      '[LocationTrackingService] Timer starting, current elapsed: $_elapsedSeconds seconds',
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _elapsedSeconds++;
        onTimerUpdate?.call(_elapsedSeconds);
        // Log every 10 seconds
        if (_elapsedSeconds % 10 == 0) {
          debugPrint(
            '[LocationTrackingService] Timer tick: $_elapsedSeconds seconds, distance: ${_totalDistanceM.toStringAsFixed(1)}m, points: ${_trackPoints.length}',
          );
        }
      }
    });
  }

  void _startUploadTimer() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(_uploadInterval, (timer) {
      _uploadPendingPoints();
    });
  }

  Future<void> _uploadPendingPoints() async {
    if (_pendingPoints.isEmpty ||
        _activeSessionId == null ||
        _accessToken == null) {
      return;
    }

    if (_pendingPoints.length < _minPointsForUpload) {
      return;
    }

    final pointsToUpload = List<RunPoint>.from(_pendingPoints);
    _pendingPoints.clear();

    final result = await _runRepository.addPoints(
      sessionId: _activeSessionId!,
      accessToken: _accessToken!,
      points: pointsToUpload,
    );

    if (!result.success) {
      // Re-add failed points
      _pendingPoints.insertAll(0, pointsToUpload);
      debugPrint(
        '[LocationTrackingService] Failed to upload points, will retry',
      );
    } else {
      debugPrint(
        '[LocationTrackingService] Uploaded ${pointsToUpload.length} points',
      );
    }
  }

  /// Pause tracking
  void pauseTracking() {
    if (!_isTracking || _isPaused) return;

    _isPaused = true;
    _pauseStartTime = DateTime.now();
    debugPrint('[LocationTrackingService] Tracking paused');
  }

  /// Resume tracking
  void resumeTracking() {
    if (!_isTracking || !_isPaused) return;

    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
    }
    _isPaused = false;
    _pauseStartTime = null;
    debugPrint('[LocationTrackingService] Tracking resumed');
  }

  /// Stop tracking and end session
  Future<RunSession?> stopTracking({bool save = true}) async {
    debugPrint('[LocationTrackingService] ========== STOP TRACKING ==========');
    debugPrint(
      '[LocationTrackingService] save: $save, isTracking: $_isTracking',
    );

    if (!_isTracking) {
      debugPrint(
        '[LocationTrackingService] WARNING: Not tracking, returning null',
      );
      return null;
    }

    // Log final stats before stopping
    debugPrint('[LocationTrackingService] Final stats:');
    debugPrint(
      '[LocationTrackingService]   - Elapsed seconds: $_elapsedSeconds',
    );
    debugPrint(
      '[LocationTrackingService]   - Total distance: ${_totalDistanceM.toStringAsFixed(1)}m',
    );
    debugPrint(
      '[LocationTrackingService]   - Track points: ${_trackPoints.length}',
    );
    debugPrint(
      '[LocationTrackingService]   - Run points: ${_runPoints.length}',
    );
    debugPrint(
      '[LocationTrackingService]   - Pending points: ${_pendingPoints.length}',
    );
    debugPrint(
      '[LocationTrackingService]   - Elevation gain: ${_elevationGainM.toStringAsFixed(1)}m',
    );
    debugPrint('[LocationTrackingService]   - Session ID: $_activeSessionId');

    // Stop streams and timers
    debugPrint('[LocationTrackingService] Stopping streams and timers...');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _timer?.cancel();
    _timer = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;

    _isTracking = false;
    _isPaused = false;

    if (!save) {
      debugPrint('[LocationTrackingService] Not saving, discarding session');
      _reset();
      return null;
    }

    // Upload any remaining points
    if (_pendingPoints.isNotEmpty &&
        _activeSessionId != null &&
        _accessToken != null) {
      debugPrint(
        '[LocationTrackingService] Uploading ${_pendingPoints.length} remaining points...',
      );
      await _runRepository.addPoints(
        sessionId: _activeSessionId!,
        accessToken: _accessToken!,
        points: _pendingPoints,
      );
    }

    // Calculate average pace
    final avgPaceSecPerKm = _totalDistanceM > 0
        ? (_elapsedSeconds / (_totalDistanceM / 1000))
        : 0.0;
    debugPrint(
      '[LocationTrackingService] Calculated avg pace: ${avgPaceSecPerKm.toStringAsFixed(1)} sec/km',
    );

    // End session on server
    if (_activeSessionId != null && _accessToken != null) {
      debugPrint('[LocationTrackingService] Ending session on server...');
      debugPrint(
        '[LocationTrackingService] Sending: movingTimeS=$_elapsedSeconds, totalDistanceM=$_totalDistanceM',
      );
      final result = await _runRepository.endRunSession(
        sessionId: _activeSessionId!,
        accessToken: _accessToken!,
        movingTimeS: _elapsedSeconds,
        totalDistanceM: _totalDistanceM,
        elevationGainM: _elevationGainM > 0 ? _elevationGainM : null,
        avgPaceSecPerKm: avgPaceSecPerKm,
      );

      if (result.success && result.data != null) {
        debugPrint(
          '[LocationTrackingService] SUCCESS: Session ended on server',
        );
        debugPrint('[LocationTrackingService] Server response: ${result.data}');
        _reset();
        return result.data;
      } else {
        debugPrint(
          '[LocationTrackingService] ERROR: Failed to end session on server: ${result.message}',
        );
      }
    } else {
      debugPrint(
        '[LocationTrackingService] WARNING: No session ID or token, creating local session',
      );
    }

    // Create local session if server fails
    debugPrint('[LocationTrackingService] Creating local session...');
    final localSession = RunSession(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: null,
      routeId: null,
      isPublic: false,
      startedAt: _startTime ?? DateTime.now(),
      endedAt: DateTime.now(),
      movingTimeS: _elapsedSeconds,
      totalDistanceM: _totalDistanceM,
      elevationGainM: _elevationGainM > 0 ? _elevationGainM : null,
      avgPaceSecPerKm: avgPaceSecPerKm,
      points: List.from(_runPoints),
      createdAt: DateTime.now(),
    );

    // Save locally
    debugPrint('[LocationTrackingService] Saving local session...');
    await _runRepository.saveRunSession(localSession, _accessToken);

    _reset();
    debugPrint(
      '[LocationTrackingService] ========== TRACKING STOPPED ==========',
    );
    return localSession;
  }

  /// Reset all tracking state
  void _reset() {
    _trackPoints.clear();
    _runPoints.clear();
    _pendingPoints.clear();
    _totalDistanceM = 0;
    _elapsedSeconds = 0;
    _currentSpeedMps = 0;
    _elevationGainM = 0;
    _lastElevation = null;
    _pausedDuration = Duration.zero;
    _startTime = null;
    _pauseStartTime = null;
    _activeSessionId = null;
    _accessToken = null;
  }

  /// Discard current tracking without saving
  /// This will also delete the session from the server if one was created
  Future<void> discardTracking() async {
    debugPrint('[LocationTrackingService] ========== DISCARD TRACKING ==========');
    debugPrint('[LocationTrackingService] Session ID to delete: $_activeSessionId');

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _timer?.cancel();
    _timer = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _isTracking = false;
    _isPaused = false;

    // Delete session from server if one was created
    if (_activeSessionId != null && _accessToken != null) {
      debugPrint('[LocationTrackingService] Deleting session $_activeSessionId from server...');
      final result = await _runRepository.deleteRunSession(
        _activeSessionId!,
        accessToken: _accessToken,
      );
      if (result.success) {
        debugPrint('[LocationTrackingService] Session deleted from server successfully');
      } else {
        debugPrint('[LocationTrackingService] Failed to delete session from server: ${result.message}');
      }
    }

    _reset();
    debugPrint('[LocationTrackingService] Tracking discarded');
  }

  /// Formatted distance string
  String get formattedDistance {
    final km = _totalDistanceM / 1000;
    if (km >= 1) {
      return '${km.toStringAsFixed(2)} km';
    }
    return '${_totalDistanceM.toInt()} m';
  }

  /// Formatted duration string
  String get formattedDuration {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatted pace string
  String get formattedPace {
    if (_totalDistanceM < 10) return '--:--/km';
    final paceSecPerKm = _elapsedSeconds / (_totalDistanceM / 1000);
    final minutes = paceSecPerKm ~/ 60;
    final seconds = (paceSecPerKm % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  /// Formatted speed string
  String get formattedSpeed {
    if (_currentSpeedMps < 0.5) return '0.0 km/h';
    final kmh = _currentSpeedMps * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  /// Dispose the service
  void dispose() {
    // Fire and forget - we can't await in dispose
    discardTracking();
  }
}
