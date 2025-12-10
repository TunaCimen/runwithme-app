import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/run_session.dart';

/// Result class for run operations
class RunResult<T> {
  final bool success;
  final T? data;
  final String? message;

  RunResult._({
    required this.success,
    this.data,
    this.message,
  });

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

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://35.158.35.102:8080',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Local storage for runs (since backend might not have run endpoints yet)
  final List<RunSession> _savedRuns = [];

  /// Save a run session
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
          return RunResult.success(savedSession, message: 'Run saved successfully');
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
  }) async {
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
          final List<dynamic> content = response.data['content'] ?? response.data;
          final runs = content
              .map((json) => RunSession.fromJson(json as Map<String, dynamic>))
              .toList();
          return RunResult.success(runs);
        }
      } catch (e) {
        // Backend might not have endpoint, return local runs
        debugPrint('[RunRepository] Backend fetch failed, returning local runs: $e');
      }

      // Return locally saved runs
      final userRuns = _savedRuns
          .where((run) => run.runnerId == userId)
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
      return RunResult.success(userRuns);
    } catch (e) {
      return RunResult.failure(message: 'Failed to fetch runs: $e');
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
        debugPrint('[RunRepository] Backend delete failed, deleting locally: $e');
      }

      // Remove from local storage
      _savedRuns.removeWhere((run) => run.id == runId);
      return RunResult.success(null, message: 'Run deleted');
    } catch (e) {
      return RunResult.failure(message: 'Failed to delete run: $e');
    }
  }

  /// Get all locally saved runs
  List<RunSession> getLocalRuns() {
    return List.unmodifiable(_savedRuns);
  }
}
