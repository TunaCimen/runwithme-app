import 'package:dio/dio.dart';
import '../../../core/models/models.dart';
import 'route_api_client.dart';
import 'models/route_dto.dart';

/// Repository for route business logic and error handling
class RouteRepository {
  final RouteApiClient _apiClient;

  RouteRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    RouteApiClient? apiClient,
  }) : _apiClient = apiClient ?? RouteApiClient(baseUrl: baseUrl);

  // ==================== Routes ====================

  /// Get nearby routes with error handling
  Future<RouteResult> getNearbyRoutes({
    required double lat,
    required double lon,
    double radius = 5000,
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
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

      return RouteResult.success(
        routes: routes,
        totalCount: response.totalElements,
      );
    } on DioException catch (e) {
      return RouteResult.failure(
        message: _handleDioError(e),
      );
    } catch (e) {
      return RouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Get public routes with error handling
  Future<RouteResult> getPublicRoutes({
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    try {
      final response = await _apiClient.getPublicRoutes(
        page: page,
        size: size,
        accessToken: accessToken,
      );

      final routes = response.content.map((dto) => dto.toModel()).toList();

      return RouteResult.success(
        routes: routes,
        totalCount: response.totalElements,
      );
    } on DioException catch (e) {
      return RouteResult.failure(
        message: _handleDioError(e),
      );
    } catch (e) {
      return RouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Get route by ID with error handling
  Future<SingleRouteResult> getRouteById({
    required int routeId,
    String? accessToken,
  }) async {
    try {
      final dto = await _apiClient.getRouteById(routeId, accessToken: accessToken);
      return SingleRouteResult.success(route: dto.toModel());
    } on DioException catch (e) {
      return SingleRouteResult.failure(message: _handleDioError(e));
    } catch (e) {
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

      return RouteResult.success(
        routes: routes,
        totalCount: routes.length,
      );
    } on DioException catch (e) {
      return RouteResult.failure(
        message: _handleDioError(e),
      );
    } catch (e) {
      return RouteResult.failure(
        message: 'An unexpected error occurred: $e',
      );
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
      await _apiClient.unlikeRoute(
        routeId: routeId,
        accessToken: accessToken,
      );

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
  Future<bool> checkIfLiked({
    required int routeId,
    required String accessToken,
  }) async {
    try {
      return await _apiClient.checkIfLiked(
        routeId: routeId,
        accessToken: accessToken,
      );
    } catch (e) {
      return false;
    }
  }

  /// Get like count
  Future<int> getLikeCount({
    required int routeId,
    String? accessToken,
  }) async {
    try {
      // Try the count endpoint first
      final count = await _apiClient.getLikeCount(
        routeId: routeId,
        accessToken: accessToken,
      );
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
        return response.totalElements;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Fetch full route details for a list of routes (to get points)
  Future<List<Route>> fetchFullRouteDetails({
    required List<Route> routes,
    String? accessToken,
  }) async {
    final fullRoutes = <Route>[];
    for (var route in routes) {
      try {
        final routeDto = await _apiClient.getRouteById(
          route.id,
          accessToken: accessToken,
        );
        fullRoutes.add(routeDto.toModel());
      } catch (e) {
        // If fetching full details fails, use the original route
        fullRoutes.add(route);
      }
    }
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
      // Get the liked routes response (contains route IDs)
      final likedRoutesResponse = await _apiClient.getUserLikedRoutes(
        userId: userId,
        page: page,
        size: size,
        accessToken: accessToken,
      );

      // Fetch the actual route details for each liked route
      final routes = <Route>[];
      for (var routeLike in likedRoutesResponse.content) {
        if (routeLike.routeId == null) continue;

        try {
          final routeDto = await _apiClient.getRouteById(
            routeLike.routeId!,
            accessToken: accessToken,
          );
          routes.add(routeDto.toModel());
        } catch (e) {
          // Skip routes that fail to load
          continue;
        }
      }

      return routes;
    } catch (e) {
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
        serverMessage = data['message'] as String? ??
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

  factory RouteResult.success({
    required List<Route> routes,
    int? totalCount,
  }) {
    return RouteResult._(
      success: true,
      routes: routes,
      totalCount: totalCount,
    );
  }

  factory RouteResult.failure({required String message}) {
    return RouteResult._(
      success: false,
      message: message,
    );
  }
}

/// Result class for single route operations
class SingleRouteResult {
  final bool success;
  final Route? route;
  final String? message;

  SingleRouteResult._({
    required this.success,
    this.route,
    this.message,
  });

  factory SingleRouteResult.success({required Route route}) {
    return SingleRouteResult._(
      success: true,
      route: route,
    );
  }

  factory SingleRouteResult.failure({required String message}) {
    return SingleRouteResult._(
      success: false,
      message: message,
    );
  }
}

/// Result class for route like operations
class RouteLikeResult {
  final bool success;
  final RouteLike? routeLike;
  final String? message;

  RouteLikeResult._({
    required this.success,
    this.routeLike,
    this.message,
  });

  factory RouteLikeResult.success({RouteLike? routeLike}) {
    return RouteLikeResult._(
      success: true,
      routeLike: routeLike,
    );
  }

  factory RouteLikeResult.failure({required String message}) {
    return RouteLikeResult._(
      success: false,
      message: message,
    );
  }
}
