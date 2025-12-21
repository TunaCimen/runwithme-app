import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/run_session.dart';

/// Result class for run operations
class RunResult<T> {
  final bool success;
  final T? data;
  final String? message;

  RunResult._({required this.success, this.data, this.message});

  factory RunResult.success(T data, {String? message}) {
    return RunResult._(success: true, data: data, message: message);
  }

  factory RunResult.failure({String? message}) {
    return RunResult._(success: false, message: message);
  }
}

/// Repository for run session operations
class RunRepository {
  static final RunRepository _instance = RunRepository._internal();
  factory RunRepository() => _instance;
  RunRepository._internal();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://35.158.35.102:8080',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Local storage for runs (fallback if backend fails)
  final List<RunSession> _savedRuns = [];

  // Cache for user runs
  final Map<String, List<RunSession>> _userRunsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheDuration = Duration(minutes: 5);

  /// Start a new run session on the server
  Future<RunResult<RunSession>> startRunSession({
    required String accessToken,
    int? routeId,
    bool isPublic = false,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.post(
        '/api/v1/run-sessions',
        data: {if (routeId != null) 'routeId': routeId, 'isPublic': isPublic},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final session = RunSession.fromJson(response.data);
        debugPrint('[RunRepository] Started run session: ${session.id}');
        return RunResult.success(session, message: 'Run session started');
      }

      return RunResult.failure(message: 'Failed to start run session');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error starting run session: ${e.message}');
      return RunResult.failure(
        message: e.response?.data?['message'] ?? 'Network error',
      );
    } catch (e) {
      debugPrint('[RunRepository] Error starting run session: $e');
      return RunResult.failure(message: 'Failed to start run session');
    }
  }

  /// Add a single point to an active run session
  Future<RunResult<void>> addPoint({
    required int sessionId,
    required String accessToken,
    required double latitude,
    required double longitude,
    double? elevationM,
    double? speedMps,
    DateTime? timestamp,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.post(
        '/api/v1/run-sessions/$sessionId/point',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          if (elevationM != null) 'elevationM': elevationM,
          if (speedMps != null) 'speedMps': speedMps,
          'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return RunResult.success(null);
      }

      return RunResult.failure(message: 'Failed to add point');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error adding point: ${e.message}');
      return RunResult.failure(message: 'Network error');
    } catch (e) {
      return RunResult.failure(message: 'Failed to add point');
    }
  }

  /// Add multiple points to an active run session
  Future<RunResult<void>> addPoints({
    required int sessionId,
    required String accessToken,
    required List<RunPoint> points,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.post(
        '/api/v1/run-sessions/$sessionId/points',
        data: {
          'points': points
              .map(
                (p) => {
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                  if (p.elevationM != null) 'elevationM': p.elevationM,
                  if (p.speedMps != null) 'speedMps': p.speedMps,
                  'timestamp': p.timestamp.toIso8601String(),
                },
              )
              .toList(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return RunResult.success(null);
      }

      return RunResult.failure(message: 'Failed to add points');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error adding points: ${e.message}');
      return RunResult.failure(message: 'Network error');
    } catch (e) {
      return RunResult.failure(message: 'Failed to add points');
    }
  }

  /// End a run session
  Future<RunResult<RunSession>> endRunSession({
    required int sessionId,
    required String accessToken,
    required int movingTimeS,
    required double totalDistanceM,
    double? elevationGainM,
    double? avgPaceSecPerKm,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final requestData = {
        'movingTimeS': movingTimeS,
        'totalDistanceM': totalDistanceM,
        if (elevationGainM != null) 'elevationGainM': elevationGainM,
        if (avgPaceSecPerKm != null) 'avgPaceSecPerKm': avgPaceSecPerKm,
      };

      debugPrint(
        '[RunRepository] endRunSession: POST /api/v1/run-sessions/$sessionId/end',
      );
      debugPrint('[RunRepository] Request data: $requestData');

      final response = await _dio.post(
        '/api/v1/run-sessions/$sessionId/end',
        data: requestData,
      );

      debugPrint('[RunRepository] Response status: ${response.statusCode}');
      debugPrint('[RunRepository] Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final session = RunSession.fromJson(response.data);
        // Clear cache since we have a new run
        _userRunsCache.clear();
        debugPrint('[RunRepository] Ended run session: ${session.id}');
        debugPrint(
          '[RunRepository] Parsed session: movingTimeS=${session.movingTimeS}, totalDistanceM=${session.totalDistanceM}',
        );
        return RunResult.success(session, message: 'Run session ended');
      }

      return RunResult.failure(message: 'Failed to end run session');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error ending run session: ${e.message}');
      debugPrint('[RunRepository] Error response: ${e.response?.data}');
      return RunResult.failure(
        message: e.response?.data?['message'] ?? 'Network error',
      );
    } catch (e) {
      debugPrint('[RunRepository] Error ending run session: $e');
      return RunResult.failure(message: 'Failed to end run session');
    }
  }

  /// Get current user's active run session (if any)
  Future<RunResult<RunSession?>> getActiveSession({
    required String accessToken,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.get('/api/v1/run-sessions/me/active');

      if (response.statusCode == 200) {
        if (response.data != null && response.data is Map) {
          final session = RunSession.fromJson(response.data);
          return RunResult.success(session);
        }
        return RunResult.success(null);
      }

      return RunResult.success(null);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return RunResult.success(null);
      }
      debugPrint('[RunRepository] Error getting active session: ${e.message}');
      return RunResult.failure(message: 'Network error');
    } catch (e) {
      return RunResult.failure(message: 'Failed to get active session');
    }
  }

  /// Save a completed run session (legacy method - now uses startRunSession + endRunSession)
  Future<RunResult<RunSession>> saveRunSession(
    RunSession session,
    String? accessToken,
  ) async {
    try {
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      // Try to save to backend
      try {
        final response = await _dio.post(
          '/api/v1/run-sessions',
          data: session.toJson(),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final savedSession = RunSession.fromJson(response.data);
          _savedRuns.add(savedSession);
          // Clear cache
          _userRunsCache.clear();
          return RunResult.success(
            savedSession,
            message: 'Run saved successfully',
          );
        }
      } catch (e) {
        // Backend endpoint might not exist yet, save locally
        debugPrint('[RunRepository] Backend save failed, saving locally: $e');
      }

      // Save locally if backend fails
      final localSession = session.copyWith(
        id: DateTime.now().millisecondsSinceEpoch,
      );
      _savedRuns.add(localSession);
      return RunResult.success(localSession, message: 'Run saved locally');
    } catch (e) {
      return RunResult.failure(message: 'Failed to save run: $e');
    }
  }

  /// Get user's run history
  Future<RunResult<List<RunSession>>> getUserRuns(
    String userId, {
    String? accessToken,
    int page = 0,
    int size = 20,
    bool forceRefresh = false,
  }) async {
    // Check cache
    final cacheKey = '${userId}_${page}_$size';
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final cached = _userRunsCache[cacheKey];
      if (cached != null) {
        debugPrint('[RunRepository] Returning cached runs for $userId');
        return RunResult.success(cached);
      }
    }

    try {
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      try {
        final response = await _dio.get(
          '/api/v1/run-sessions/user/$userId',
          queryParameters: {'page': page, 'size': size},
        );

        if (response.statusCode == 200) {
          final List<dynamic> content =
              response.data['content'] ?? response.data;
          final runs = content
              .map((json) => RunSession.fromJson(json as Map<String, dynamic>))
              .toList();

          // Cache the result
          _userRunsCache[cacheKey] = runs;
          _cacheTimestamps[cacheKey] = DateTime.now();

          return RunResult.success(runs);
        }
      } catch (e) {
        // Backend might not have endpoint, return local runs
        debugPrint(
          '[RunRepository] Backend fetch failed, returning local runs: $e',
        );
      }

      // Return locally saved runs
      final userRuns = _savedRuns.where((run) => run.userId == userId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return RunResult.success(userRuns);
    } catch (e) {
      return RunResult.failure(message: 'Failed to fetch runs: $e');
    }
  }

  /// Get public run sessions
  Future<RunResult<List<RunSession>>> getPublicRunSessions({
    String? accessToken,
    int page = 0,
    int size = 20,
  }) async {
    try {
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await _dio.get(
        '/api/v1/run-sessions/public',
        queryParameters: {'page': page, 'size': size},
      );

      if (response.statusCode == 200) {
        final List<dynamic> content = response.data['content'] ?? response.data;
        final runs = content
            .map((json) => RunSession.fromJson(json as Map<String, dynamic>))
            .toList();
        return RunResult.success(runs);
      }

      return RunResult.failure(message: 'Failed to get public runs');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error getting public runs: ${e.message}');
      return RunResult.failure(message: 'Network error');
    } catch (e) {
      return RunResult.failure(message: 'Failed to get public runs');
    }
  }

  /// Get run sessions for a specific route
  Future<RunResult<List<RunSession>>> getRunSessionsByRoute({
    required int routeId,
    String? accessToken,
    int page = 0,
    int size = 20,
  }) async {
    try {
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await _dio.get(
        '/api/v1/run-sessions/route/$routeId',
        queryParameters: {'page': page, 'size': size},
      );

      if (response.statusCode == 200) {
        final List<dynamic> content = response.data['content'] ?? response.data;
        final runs = content
            .map((json) => RunSession.fromJson(json as Map<String, dynamic>))
            .toList();
        return RunResult.success(runs);
      }

      return RunResult.failure(message: 'Failed to get route runs');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error getting route runs: ${e.message}');
      return RunResult.failure(message: 'Network error');
    } catch (e) {
      return RunResult.failure(message: 'Failed to get route runs');
    }
  }

  /// Get a single run session by ID
  Future<RunResult<RunSession>> getRunSession(
    int runId, {
    String? accessToken,
  }) async {
    try {
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      try {
        final response = await _dio.get('/api/v1/run-sessions/$runId');

        if (response.statusCode == 200) {
          final session = RunSession.fromJson(response.data);
          return RunResult.success(session);
        }
      } catch (e) {
        // Try local
        debugPrint('[RunRepository] Backend fetch failed, checking local: $e');
      }

      // Check local storage
      final localSession = _savedRuns.firstWhere(
        (run) => run.id == runId,
        orElse: () => throw Exception('Run not found'),
      );
      return RunResult.success(localSession);
    } catch (e) {
      return RunResult.failure(message: 'Run not found');
    }
  }

  /// Update a run session
  Future<RunResult<RunSession>> updateRunSession(
    int runId, {
    required String accessToken,
    bool? isPublic,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.put(
        '/api/v1/run-sessions/$runId',
        data: {if (isPublic != null) 'isPublic': isPublic},
      );

      if (response.statusCode == 200) {
        final session = RunSession.fromJson(response.data);
        // Clear cache
        _userRunsCache.clear();
        return RunResult.success(session, message: 'Run updated');
      }

      return RunResult.failure(message: 'Failed to update run');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error updating run: ${e.message}');
      return RunResult.failure(message: 'Network error');
    } catch (e) {
      return RunResult.failure(message: 'Failed to update run');
    }
  }

  /// Create a run session from an existing route
  /// This saves the route as a previous run for the logged-in user
  Future<RunResult<RunSession>> createRunFromRoute({
    required int routeId,
    required String accessToken,
  }) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      final response = await _dio.post(
        '/api/v1/run-sessions/from-route/$routeId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final session = RunSession.fromJson(response.data);
        // Clear cache since we have a new run
        _userRunsCache.clear();
        debugPrint('[RunRepository] Created run from route: ${session.id}');
        return RunResult.success(session, message: 'Route saved as run');
      }

      return RunResult.failure(message: 'Failed to create run from route');
    } on DioException catch (e) {
      debugPrint('[RunRepository] Error creating run from route: ${e.message}');
      return RunResult.failure(
        message: e.response?.data?['message'] ?? 'Network error',
      );
    } catch (e) {
      debugPrint('[RunRepository] Error creating run from route: $e');
      return RunResult.failure(message: 'Failed to create run from route');
    }
  }

  /// Delete a run session
  Future<RunResult<void>> deleteRunSession(
    int runId, {
    String? accessToken,
  }) async {
    try {
      if (accessToken != null) {
        _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      }

      try {
        await _dio.delete('/api/v1/run-sessions/$runId');
      } catch (e) {
        // Try local deletion
        debugPrint(
          '[RunRepository] Backend delete failed, deleting locally: $e',
        );
      }

      // Remove from local storage
      _savedRuns.removeWhere((run) => run.id == runId);
      // Clear cache
      _userRunsCache.clear();
      return RunResult.success(null, message: 'Run deleted');
    } catch (e) {
      return RunResult.failure(message: 'Failed to delete run: $e');
    }
  }

  /// Get all locally saved runs
  List<RunSession> getLocalRuns() {
    return List.unmodifiable(_savedRuns);
  }

  /// Clear all caches
  void clearCache() {
    _userRunsCache.clear();
    _cacheTimestamps.clear();
    debugPrint('[RunRepository] Cache cleared');
  }

  /// Check if cache is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }
}
