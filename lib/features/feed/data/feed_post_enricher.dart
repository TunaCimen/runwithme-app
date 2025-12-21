import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/route.dart';
import '../../../core/models/run_session.dart';
import '../../map/data/route_repository.dart';
import '../../run/data/run_naming_service.dart';
import '../../run/data/run_repository.dart';
import 'models/feed_post_dto.dart';

/// Service to enrich feed posts with route/run details
/// Fetches missing data using routeId/runSessionId
class FeedPostEnricher {
  final RouteRepository _routeRepository;
  final RunRepository _runRepository;

  FeedPostEnricher({
    RouteRepository? routeRepository,
    RunRepository? runRepository,
  }) : _routeRepository = routeRepository ?? RouteRepository.instance,
       _runRepository = runRepository ?? RunRepository();

  /// Enrich a list of posts with route/run details
  /// Fetches data only for posts that have routeId/runSessionId but missing details
  Future<List<FeedPostDto>> enrichPosts(
    List<FeedPostDto> posts, {
    String? accessToken,
  }) async {
    if (posts.isEmpty) return posts;

    final enrichedPosts = <FeedPostDto>[];
    final routeIds = <int>{};
    final runSessionIds = <int>{};

    // Collect IDs that need fetching
    for (final post in posts) {
      if (post.routeId != null && _needsRouteData(post)) {
        routeIds.add(post.routeId!);
        debugPrint(
          '[FeedPostEnricher] Post ${post.id} needs route data (routeId=${post.routeId})',
        );
      }
      if (post.runSessionId != null && _needsRunData(post)) {
        runSessionIds.add(post.runSessionId!);
        debugPrint(
          '[FeedPostEnricher] Post ${post.id} needs run data (runSessionId=${post.runSessionId})',
        );
      } else if (post.runSessionId != null) {
        debugPrint(
          '[FeedPostEnricher] Post ${post.id} already has run data - points: ${post.routePoints?.length ?? 0}, startLat: ${post.startPointLat}',
        );
      }
    }

    debugPrint(
      '[FeedPostEnricher] Enriching ${posts.length} posts - '
      '${routeIds.length} routes, ${runSessionIds.length} runs to fetch',
    );

    // Fetch routes and runs in parallel
    final routesMap = <int, Route>{};
    final runsMap = <int, RunSession>{};

    await Future.wait([
      _fetchRoutes(routeIds, routesMap, accessToken),
      _fetchRunSessions(runSessionIds, runsMap, accessToken),
    ]);

    // Enrich each post
    for (final post in posts) {
      var enrichedPost = post;

      // Enrich with route data
      if (post.routeId != null && routesMap.containsKey(post.routeId)) {
        final route = routesMap[post.routeId]!;
        enrichedPost = _enrichWithRoute(enrichedPost, route);
      }

      // Enrich with run data (async for run naming)
      if (post.runSessionId != null && runsMap.containsKey(post.runSessionId)) {
        final run = runsMap[post.runSessionId]!;
        enrichedPost = await _enrichWithRun(enrichedPost, run);
      }

      enrichedPosts.add(enrichedPost);
    }

    return enrichedPosts;
  }

  /// Check if post needs route data (has routeId but missing key fields)
  bool _needsRouteData(FeedPostDto post) {
    return post.routeDistanceM == null &&
        post.startPointLat == null &&
        (post.routePoints == null || post.routePoints!.isEmpty);
  }

  /// Check if post needs run data (has runSessionId but missing route points for map display)
  bool _needsRunData(FeedPostDto post) {
    // Always fetch if we don't have route points for the map
    final hasNoPoints = post.routePoints == null || post.routePoints!.isEmpty;
    final hasNoCoordinates = post.startPointLat == null;
    return hasNoPoints && hasNoCoordinates;
  }

  /// Fetch routes by IDs
  Future<void> _fetchRoutes(
    Set<int> routeIds,
    Map<int, Route> routesMap,
    String? accessToken,
  ) async {
    for (final routeId in routeIds) {
      try {
        final result = await _routeRepository.getRouteById(
          routeId: routeId,
          accessToken: accessToken,
        );
        if (result.success && result.route != null) {
          routesMap[routeId] = result.route!;
          debugPrint(
            '[FeedPostEnricher] Fetched route $routeId: '
            '${result.route!.points.length} points, '
            '${result.route!.distanceM}m',
          );
        }
      } catch (e) {
        debugPrint('[FeedPostEnricher] Failed to fetch route $routeId: $e');
      }
    }
  }

  /// Fetch run sessions by IDs
  Future<void> _fetchRunSessions(
    Set<int> runSessionIds,
    Map<int, RunSession> runsMap,
    String? accessToken,
  ) async {
    for (final runId in runSessionIds) {
      try {
        final result = await _runRepository.getRunSession(
          runId,
          accessToken: accessToken,
        );
        if (result.success && result.data != null) {
          runsMap[runId] = result.data!;
          debugPrint(
            '[FeedPostEnricher] Fetched run $runId: '
            '${result.data!.points.length} points, '
            '${result.data!.totalDistanceM}m',
          );
        }
      } catch (e) {
        debugPrint('[FeedPostEnricher] Failed to fetch run $runId: $e');
      }
    }
  }

  /// Enrich post with route data
  FeedPostDto _enrichWithRoute(FeedPostDto post, Route route) {
    // Convert route points to the format expected by FeedPostDto
    List<Map<String, double>>? routePoints;
    if (route.points.isNotEmpty) {
      routePoints = route.points
          .map(
            (p) => <String, double>{
              'latitude': p.latitude,
              'longitude': p.longitude,
            },
          )
          .toList();
    }

    return post.copyWith(
      routeDistanceM: route.distanceM,
      routeDurationS: route.estimatedDurationS,
      routeTitle: route.title,
      startPointLat: route.startPointLat,
      startPointLon: route.startPointLon,
      endPointLat: route.endPointLat,
      endPointLon: route.endPointLon,
      routePoints: routePoints,
    );
  }

  /// Enrich post with run session data
  Future<FeedPostDto> _enrichWithRun(FeedPostDto post, RunSession run) async {
    // Convert run points to the format expected by FeedPostDto
    List<Map<String, double>>? routePoints;
    if (run.points.isNotEmpty) {
      routePoints = run.points
          .map(
            (p) => <String, double>{
              'latitude': p.latitude,
              'longitude': p.longitude,
            },
          )
          .toList();
    }

    // Calculate pace if we have distance and duration
    double? paceSecPerKm;
    if (run.totalDistanceM > 0 && run.movingTimeS > 0) {
      paceSecPerKm = run.movingTimeS.toDouble() / (run.totalDistanceM / 1000);
    }

    // Generate run name using the naming service
    String? runName;
    try {
      LatLng? startPoint;
      LatLng? endPoint;
      if (run.points.isNotEmpty) {
        startPoint = LatLng(
          run.points.first.latitude,
          run.points.first.longitude,
        );
        endPoint = LatLng(run.points.last.latitude, run.points.last.longitude);
      }
      runName = await RunNamingService.generateRunName(
        startTime: run.startedAt,
        startPoint: startPoint,
        endPoint: endPoint,
      );
      debugPrint('[FeedPostEnricher] Generated run name: $runName');
    } catch (e) {
      debugPrint('[FeedPostEnricher] Failed to generate run name: $e');
    }

    return post.copyWith(
      runDistanceM: run.totalDistanceM,
      runDurationS: run.movingTimeS,
      runPaceSecPerKm: paceSecPerKm ?? run.avgPaceSecPerKm,
      routeTitle: runName,
      startPointLat: run.points.isNotEmpty ? run.points.first.latitude : null,
      startPointLon: run.points.isNotEmpty ? run.points.first.longitude : null,
      endPointLat: run.points.isNotEmpty ? run.points.last.latitude : null,
      endPointLon: run.points.isNotEmpty ? run.points.last.longitude : null,
      routePoints: routePoints,
    );
  }
}
