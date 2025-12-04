import 'package:dio/dio.dart';
import '../../../core/api/base_api_client.dart';
import 'models/route_dto.dart';
import 'models/route_like_dto.dart';

/// API client for route-related endpoints
class RouteApiClient extends BaseApiClient {
  RouteApiClient({
    String baseUrl = 'http://35.158.35.102:8080',
    Dio? dio,
  }) : super(baseUrl: '$baseUrl/api/v1');

  // ==================== Routes ====================

  /// Get all routes (paginated)
  Future<PaginatedRouteResponse> getRoutes({
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/routes',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    return PaginatedRouteResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get public routes (paginated)
  Future<PaginatedRouteResponse> getPublicRoutes({
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/routes/public',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    return PaginatedRouteResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get nearby routes
  Future<PaginatedRouteResponse> getNearbyRoutes({
    required double lat,
    required double lon,
    double radius = 5000, // meters
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/routes/nearby',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'radius': radius,
        'page': page,
        'size': size,
      },
    );

    return PaginatedRouteResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get route by ID
  Future<RouteDto> getRouteById(int routeId, {String? accessToken}) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get('/routes/$routeId');
    return RouteDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Create a new route
  Future<RouteDto> createRoute({
    required RouteDto route,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);

    final response = await dio.post(
      '/routes',
      data: route.toJson(),
    );

    return RouteDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update a route (full replacement)
  Future<RouteDto> updateRoute({
    required int routeId,
    required RouteDto route,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);

    final response = await dio.put(
      '/routes/$routeId',
      data: route.toJson(),
    );

    return RouteDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update route with only editable fields (using PUT since PATCH is not supported)
  Future<RouteDto> updateRouteFields({
    required int routeId,
    String? title,
    String? description,
    String? difficulty,
    bool? isPublic,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);

    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (difficulty != null) data['difficulty'] = difficulty;
    if (isPublic != null) data['public'] = isPublic;

    final response = await dio.put(
      '/routes/$routeId',
      data: data,
    );

    return RouteDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete a route
  Future<void> deleteRoute({
    required int routeId,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);
    await dio.delete('/routes/$routeId');
  }

  /// Get routes by difficulty
  Future<PaginatedRouteResponse> getRoutesByDifficulty({
    required String difficulty,
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/routes/difficulty/$difficulty',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    return PaginatedRouteResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get similar routes (KNN)
  Future<List<RouteDto>> getSimilarRoutes({
    required int routeId,
    double maxDistance = 5000,
    int limit = 5,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/routes/$routeId/similar',
      queryParameters: {
        'maxDistance': maxDistance,
        'limit': limit,
      },
    );

    return (response.data as List)
        .map((route) => RouteDto.fromJson(route as Map<String, dynamic>))
        .toList();
  }

  // ==================== Route Likes ====================

  /// Like a route
  Future<RouteLikeDto> likeRoute({
    required int routeId,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);

    final response = await dio.post('/route-likes/route/$routeId');
    return RouteLikeDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Unlike a route
  Future<void> unlikeRoute({
    required int routeId,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);
    await dio.delete('/route-likes/route/$routeId');
  }

  /// Check if current user liked a route
  Future<bool> checkIfLiked({
    required int routeId,
    required String accessToken,
  }) async {
    setAuthToken(accessToken);

    try {
      final response = await dio.get('/route-likes/route/$routeId/check');
      return response.data as bool;
    } catch (e) {
      return false;
    }
  }

  /// Get like count for a route
  Future<int> getLikeCount({
    required int routeId,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get('/route-likes/route/$routeId/count');
    final data = response.data;

    // Handle different response formats
    if (data is num) {
      return data.toInt();
    } else if (data is Map) {
      // Try common field names for count
      return (data['count'] as num?)?.toInt() ??
             (data['likeCount'] as num?)?.toInt() ??
             (data['total'] as num?)?.toInt() ?? 0;
    } else if (data is String) {
      return int.tryParse(data) ?? 0;
    }
    return 0;
  }

  /// Get likes for a route (paginated)
  Future<PaginatedRouteLikeResponse> getRouteLikes({
    required int routeId,
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/route-likes/route/$routeId',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    return PaginatedRouteLikeResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get user's liked routes (paginated)
  Future<PaginatedRouteLikeResponse> getUserLikedRoutes({
    required String userId,
    int page = 0,
    int size = 10,
    String? accessToken,
  }) async {
    if (accessToken != null) {
      setAuthToken(accessToken);
    }

    final response = await dio.get(
      '/route-likes/user/$userId',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );

    return PaginatedRouteLikeResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
