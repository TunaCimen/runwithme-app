import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/models.dart';
import 'route_api_client.dart';
import 'models/route_dto.dart';

/// Repository for route business logic and error handling
/// Uses singleton pattern to share cache across all pages
class RouteRepository {
  // Singleton instance
  static RouteRepository? _instance;

  /// Get the singleton instance
  static RouteRepository get instance {
    _instance ??= RouteRepository._internal();
    return _instance!;
  }

  final RouteApiClient _apiClient;

  // ==================== Cache ====================

  /// Cache for individual routes by ID
  final Map<int, Route> _routeCache = {};

  /// Cache for public routes list
  List<Route>? _publicRoutesCache;
  int? _publicRoutesTotalCount;

  /// Cache for nearby routes (key: "lat,lon,radius")
  final Map<String, List<Route>> _nearbyRoutesCache = {};
  final Map<String, int> _nearbyRoutesTotalCount = {};

  /// Cache for like statuses
  final Map<int, bool> _likeStatusCache = {};
  final Map<int, int> _likeCountCache = {};

  /// Cache timestamps for expiry
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Cache duration (default 5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Private constructor for singleton
  RouteRepository._internal({
    String baseUrl = 'http://35.158.35.102:8080',
    RouteApiClient? apiClient,
  }) : _apiClient = apiClient ?? RouteApiClient(baseUrl: baseUrl);

  /// Factory constructor that returns singleton
  factory RouteRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    RouteApiClient? apiClient,
  }) {
    _instance ??= RouteRepository._internal(
      baseUrl: baseUrl,
      apiClient: apiClient,
    );
    return _instance!;
  }

  // ==================== Cache Management ====================

  /// Check if cache entry is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  /// Update cache timestamp
  void _updateCacheTimestamp(String cacheKey) {
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Clear all caches (for pull-to-refresh)
  void clearCache() {
    _routeCache.clear();
    _publicRoutesCache = null;
    _publicRoutesTotalCount = null;
    _nearbyRoutesCache.clear();
    _nearbyRoutesTotalCount.clear();
    _likeStatusCache.clear();
    _likeCountCache.clear();
    _cacheTimestamps.clear();
  }

  /// Clear only route list caches (keeps individual routes)
  void clearListCaches() {
    _publicRoutesCache = null;
    _publicRoutesTotalCount = null;
    _nearbyRoutesCache.clear();
    _nearbyRoutesTotalCount.clear();
    _cacheTimestamps.removeWhere(
      (key, _) => key == 'publicRoutes' || key.startsWith('nearby_'),
    );
  }

  // ==================== Routes ====================

  /// Get nearby routes with error handling
  /// Set [forceRefresh] to true to bypass cache (e.g., on pull-to-refresh)
  Future<RouteResult> getNearbyRoutes({
    required double lat,
    required double lon,
    double radius = 5000,
    int page = 0,
    int size = 10,
    String? accessToken,
    bool forceRefresh = false,
  }) async {
    // Cache key based on location and radius (round lat/lon to reduce cache misses)
    final cacheKey =
        'nearby_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}_$radius';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && page == 0 && _isCacheValid(cacheKey)) {
      final cachedRoutes = _nearbyRoutesCache[cacheKey];
      if (cachedRoutes != null) {
        return RouteResult.success(
          routes: cachedRoutes,
          totalCount: _nearbyRoutesTotalCount[cacheKey],
        );
      }
    }

    try {
      final response = await _apiClient.getNearbyRoutes(
        lat: lat,
        lon: lon,
        radius: radius,
        page: page,
        size: size,
        accessToken: accessToken,
      );

      final routes = response.content.map((dto) => dto.toModel()).toList();

      // Cache the results (only first page for simplicity)
      if (page == 0) {
        _nearbyRoutesCache[cacheKey] = routes;
        _nearbyRoutesTotalCount[cacheKey] = response.totalElements;
        _updateCacheTimestamp(cacheKey);

        // Also cache individual routes
        for (final route in routes) {
          _routeCache[route.id] = route;
        }
      }

      return RouteResult.success(
        routes: routes,
        totalCount: response.totalElements,
      );
    } on DioException catch (e) {
      return RouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      return RouteResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Get public routes with error handling
  /// Set [forceRefresh] to true to bypass cache (e.g., on pull-to-refresh)
  Future<RouteResult> getPublicRoutes({
    int page = 0,
    int size = 10,
    String? accessToken,
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'publicRoutes';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && page == 0 && _isCacheValid(cacheKey)) {
      final cachedRoutes = _publicRoutesCache;
      if (cachedRoutes != null) {
        return RouteResult.success(
          routes: cachedRoutes,
          totalCount: _publicRoutesTotalCount,
        );
      }
    }

    try {
      final response = await _apiClient.getPublicRoutes(
        page: page,
        size: size,
        accessToken: accessToken,
      );

      final routes = response.content.map((dto) => dto.toModel()).toList();

      // Cache the results (only first page for simplicity)
      if (page == 0) {
        _publicRoutesCache = routes;
        _publicRoutesTotalCount = response.totalElements;
        _updateCacheTimestamp(cacheKey);

        // Also cache individual routes
        for (final route in routes) {
          _routeCache[route.id] = route;
        }
      }

      return RouteResult.success(
        routes: routes,
        totalCount: response.totalElements,
      );
    } on DioException catch (e) {
      return RouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      return RouteResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Get route by ID with error handling
  /// Set [forceRefresh] to true to bypass cache (e.g., on pull-to-refresh)
  Future<SingleRouteResult> getRouteById({
    required int routeId,
    String? accessToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'route_$routeId';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final cachedRoute = _routeCache[routeId];
      if (cachedRoute != null) {
        return SingleRouteResult.success(route: cachedRoute);
      }
    }

    try {
      debugPrint('[RouteRepository] Fetching route $routeId from API...');
      final dto = await _apiClient.getRouteById(
        routeId,
        accessToken: accessToken,
      );
      debugPrint('[RouteRepository] Route DTO received for $routeId:');
      debugPrint('[RouteRepository]   title: ${dto.title}');
      debugPrint(
        '[RouteRepository]   points count: ${dto.points?.length ?? 0}',
      );
      debugPrint(
        '[RouteRepository]   startPoint: (${dto.startPointLat}, ${dto.startPointLon})',
      );
      debugPrint(
        '[RouteRepository]   endPoint: (${dto.endPointLat}, ${dto.endPointLon})',
      );
      if (dto.points != null && dto.points!.isNotEmpty) {
        debugPrint('[RouteRepository]   First DTO point: ${dto.points!.first}');
        debugPrint('[RouteRepository]   Last DTO point: ${dto.points!.last}');
      }

      final route = dto.toModel();
      debugPrint('[RouteRepository] Route model created for $routeId:');
      debugPrint(
        '[RouteRepository]   model points count: ${route.points.length}',
      );

      // Cache the route
      _routeCache[routeId] = route;
      _updateCacheTimestamp(cacheKey);

      return SingleRouteResult.success(route: route);
    } on DioException catch (e) {
      debugPrint(
        '[RouteRepository] DioException fetching route $routeId: ${e.message}',
      );
      return SingleRouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      debugPrint('[RouteRepository] Error fetching route $routeId: $e');
      return SingleRouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Get similar routes
  Future<RouteResult> getSimilarRoutes({
    required int routeId,
    double maxDistance = 5000,
    int limit = 3,
    String? accessToken,
  }) async {
    try {
      final dtos = await _apiClient.getSimilarRoutes(
        routeId: routeId,
        maxDistance: maxDistance,
        limit: limit,
        accessToken: accessToken,
      );

      final routes = dtos.map((dto) => dto.toModel()).toList();

      return RouteResult.success(routes: routes, totalCount: routes.length);
    } on DioException catch (e) {
      return RouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      return RouteResult.failure(message: 'An unexpected error occurred: $e');
    }
  }

  /// Create a new route
  Future<SingleRouteResult> createRoute({
    required Route route,
    required String accessToken,
  }) async {
    try {
      final dto = RouteDto.fromModel(route);
      final responseDto = await _apiClient.createRoute(
        route: dto,
        accessToken: accessToken,
      );

      return SingleRouteResult.success(route: responseDto.toModel());
    } on DioException catch (e) {
      return SingleRouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      return SingleRouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Update an existing route (full replacement - may not be supported by all backends)
  Future<SingleRouteResult> updateRoute({
    required Route route,
    required String accessToken,
  }) async {
    try {
      final dto = RouteDto.fromModel(route);

      final responseDto = await _apiClient.updateRoute(
        routeId: route.id,
        route: dto,
        accessToken: accessToken,
      );

      return SingleRouteResult.success(route: responseDto.toModel());
    } on DioException catch (e) {
      return SingleRouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      return SingleRouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Update route with only editable fields
  Future<SingleRouteResult> updateRouteFields({
    required int routeId,
    String? title,
    String? description,
    String? difficulty,
    bool? isPublic,
    required String accessToken,
  }) async {
    try {
      final responseDto = await _apiClient.updateRouteFields(
        routeId: routeId,
        title: title,
        description: description,
        difficulty: difficulty,
        isPublic: isPublic,
        accessToken: accessToken,
      );

      return SingleRouteResult.success(route: responseDto.toModel());
    } on DioException catch (e) {
      return SingleRouteResult.failure(message: _handleDioError(e));
    } catch (e) {
      return SingleRouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== Route Likes ====================

  /// Like a route
  Future<RouteLikeResult> likeRoute({
    required int routeId,
    required String accessToken,
  }) async {
    try {
      final dto = await _apiClient.likeRoute(
        routeId: routeId,
        accessToken: accessToken,
      );

      // Update cache
      _likeStatusCache[routeId] = true;
      final currentCount = _likeCountCache[routeId] ?? 0;
      _likeCountCache[routeId] = currentCount + 1;
      _updateCacheTimestamp('like_$routeId');

      return RouteLikeResult.success(routeLike: dto.toModel());
    } on DioException catch (e) {
      return RouteLikeResult.failure(message: _handleDioError(e));
    } catch (e) {
      return RouteLikeResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Unlike a route
  Future<RouteLikeResult> unlikeRoute({
    required int routeId,
    required String accessToken,
  }) async {
    try {
      await _apiClient.unlikeRoute(routeId: routeId, accessToken: accessToken);

      // Update cache
      _likeStatusCache[routeId] = false;
      final currentCount = _likeCountCache[routeId] ?? 0;
      _likeCountCache[routeId] = currentCount > 0 ? currentCount - 1 : 0;
      _updateCacheTimestamp('like_$routeId');

      return RouteLikeResult.success();
    } on DioException catch (e) {
      return RouteLikeResult.failure(message: _handleDioError(e));
    } catch (e) {
      return RouteLikeResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Check if route is liked
  /// Set [forceRefresh] to true to bypass cache
  Future<bool> checkIfLiked({
    required int routeId,
    required String accessToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'like_$routeId';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh &&
        _isCacheValid(cacheKey) &&
        _likeStatusCache.containsKey(routeId)) {
      return _likeStatusCache[routeId]!;
    }

    try {
      final isLiked = await _apiClient.checkIfLiked(
        routeId: routeId,
        accessToken: accessToken,
      );

      // Cache the result
      _likeStatusCache[routeId] = isLiked;
      _updateCacheTimestamp(cacheKey);

      return isLiked;
    } catch (e) {
      return false;
    }
  }

  /// Get like count
  /// Set [forceRefresh] to true to bypass cache
  Future<int> getLikeCount({
    required int routeId,
    String? accessToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'likeCount_$routeId';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh &&
        _isCacheValid(cacheKey) &&
        _likeCountCache.containsKey(routeId)) {
      return _likeCountCache[routeId]!;
    }

    try {
      // Try the count endpoint first
      final count = await _apiClient.getLikeCount(
        routeId: routeId,
        accessToken: accessToken,
      );

      // Cache the result
      _likeCountCache[routeId] = count;
      _updateCacheTimestamp(cacheKey);

      return count;
    } catch (e) {
      // Fallback: use paginated endpoint to get totalElements
      try {
        final response = await _apiClient.getRouteLikes(
          routeId: routeId,
          page: 0,
          size: 1,
          accessToken: accessToken,
        );
        final count = response.totalElements;

        // Cache the result
        _likeCountCache[routeId] = count;
        _updateCacheTimestamp(cacheKey);

        return count;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Get cached like status without API call (returns null if not cached)
  bool? getCachedLikeStatus(int routeId) => _likeStatusCache[routeId];

  /// Get cached like count without API call (returns null if not cached)
  int? getCachedLikeCount(int routeId) => _likeCountCache[routeId];

  /// Fetch full route details for a list of routes (to get points)
  /// Uses parallel requests for better performance
  Future<List<Route>> fetchFullRouteDetails({
    required List<Route> routes,
    String? accessToken,
    int batchSize =
        10, // Limit concurrent requests to avoid overwhelming server
  }) async {
    if (routes.isEmpty) return [];

    final stopwatch = Stopwatch()..start();
    final fullRoutes = <Route>[];

    // Process routes in batches for controlled parallelism
    for (var i = 0; i < routes.length; i += batchSize) {
      final batchEnd = (i + batchSize < routes.length)
          ? i + batchSize
          : routes.length;
      final batch = routes.sublist(i, batchEnd);

      // Fetch batch in parallel
      final batchResults = await Future.wait(
        batch.map((route) async {
          try {
            final routeDto = await _apiClient.getRouteById(
              route.id,
              accessToken: accessToken,
            );
            return routeDto.toModel();
          } catch (e) {
            // If fetching full details fails, use the original route
            return route;
          }
        }),
      );

      fullRoutes.addAll(batchResults);
    }

    stopwatch.stop();
    return fullRoutes;
  }

  /// Get user's liked routes
  Future<List<Route>> getUserLikedRoutes({
    required String userId,
    int page = 0,
    int size = 50,
    required String accessToken,
  }) async {
    try {
      debugPrint('[RouteRepository] getUserLikedRoutes for user: $userId');
      // Get the liked routes response (contains route IDs)
      final likedRoutesResponse = await _apiClient.getUserLikedRoutes(
        userId: userId,
        page: page,
        size: size,
        accessToken: accessToken,
      );

      debugPrint(
        '[RouteRepository] Liked routes response: ${likedRoutesResponse.content.length} items',
      );
      for (var routeLike in likedRoutesResponse.content) {
        debugPrint(
          '[RouteRepository]   routeLike: routeId=${routeLike.routeId}',
        );
      }

      // Fetch the actual route details for each liked route
      final routes = <Route>[];
      for (var routeLike in likedRoutesResponse.content) {
        if (routeLike.routeId == null) {
          debugPrint(
            '[RouteRepository]   Skipping routeLike with null routeId',
          );
          continue;
        }

        try {
          debugPrint(
            '[RouteRepository]   Fetching route ${routeLike.routeId}...',
          );
          final routeDto = await _apiClient.getRouteById(
            routeLike.routeId!,
            accessToken: accessToken,
          );
          final route = routeDto.toModel();
          debugPrint(
            '[RouteRepository]   Route ${route.id}: ${route.title}, ${route.points.length} points',
          );
          routes.add(route);
        } catch (e) {
          debugPrint(
            '[RouteRepository]   Error fetching route ${routeLike.routeId}: $e',
          );
          // Skip routes that fail to load
          continue;
        }
      }

      debugPrint('[RouteRepository] Returning ${routes.length} routes');
      return routes;
    } catch (e) {
      debugPrint('[RouteRepository] getUserLikedRoutes error: $e');
      return [];
    }
  }

  // ==================== Error Handling ====================

  String _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      // Try to extract error message from response
      String? serverMessage;
      if (data is Map) {
        serverMessage =
            data['message'] as String? ??
            data['error'] as String? ??
            data['detail'] as String?;
      } else if (data is String && data.isNotEmpty) {
        serverMessage = data;
      }

      switch (statusCode) {
        case 400:
          return serverMessage ?? 'Invalid request: Bad request';
        case 401:
          return 'Unauthorized. Please log in again.';
        case 403:
          return serverMessage ?? 'Access forbidden';
        case 404:
          return 'Route not found';
        case 409:
          return serverMessage ?? 'Conflict occurred';
        case 500:
          return serverMessage ?? 'Server error. Please try again later.';
        default:
          return serverMessage ?? 'Error: Unknown error ($statusCode)';
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Please check your internet connection.';
    } else {
      return 'Network error: ${e.message}';
    }
  }
}

// ==================== Result Classes ====================

/// Result class for route operations
class RouteResult {
  final bool success;
  final List<Route>? routes;
  final int? totalCount;
  final String? message;

  RouteResult._({
    required this.success,
    this.routes,
    this.totalCount,
    this.message,
  });

  factory RouteResult.success({required List<Route> routes, int? totalCount}) {
    return RouteResult._(success: true, routes: routes, totalCount: totalCount);
  }

  factory RouteResult.failure({required String message}) {
    return RouteResult._(success: false, message: message);
  }
}

/// Result class for single route operations
class SingleRouteResult {
  final bool success;
  final Route? route;
  final String? message;

  SingleRouteResult._({required this.success, this.route, this.message});

  factory SingleRouteResult.success({required Route route}) {
    return SingleRouteResult._(success: true, route: route);
  }

  factory SingleRouteResult.failure({required String message}) {
    return SingleRouteResult._(success: false, message: message);
  }
}

/// Result class for route like operations
class RouteLikeResult {
  final bool success;
  final RouteLike? routeLike;
  final String? message;

  RouteLikeResult._({required this.success, this.routeLike, this.message});

  factory RouteLikeResult.success({RouteLike? routeLike}) {
    return RouteLikeResult._(success: true, routeLike: routeLike);
  }

  factory RouteLikeResult.failure({required String message}) {
    return RouteLikeResult._(success: false, message: message);
  }
}
