// Test script for Route API - specifically testing is_public update
import 'package:dio/dio.dart';
import 'features/auth/data/auth_api_client.dart';
import 'features/auth/data/models/auth_dto.dart';
import 'features/map/data/route_api_client.dart';
import 'features/map/data/models/route_dto.dart';

const String baseUrl = 'http://35.158.35.102:8080';

// Test credentials - update these with valid credentials
const String testUsername = 'idil';
const String testPassword = '123456';

Future<void> main() async {
  print('=== Route API Test: Update is_public ===\n');

  var authClient = AuthApiClient(baseUrl: baseUrl);
  var routeClient = RouteApiClient(baseUrl: baseUrl);

  String? accessToken;
  int? testRouteId;

  try {
    // Step 1: Authenticate to get access token
    print('Step 1: Authenticating...');
    final authResponse = await authClient.login(
      LoginRequestDto(username: testUsername, password: testPassword),
    );
    accessToken = authResponse.accessToken;
    print('✓ Logged in as: ${authResponse.user.username}');
    print('  User ID: ${authResponse.user.userId}');
    print('');

    // Step 2: Get user's existing routes or create a test route
    print('Step 2: Getting existing routes...');
    final routesResponse = await routeClient.getRoutes(
      accessToken: accessToken,
      page: 0,
      size: 10,
    );

    if (routesResponse.content.isEmpty) {
      // Create a test route if none exist
      print('  No routes found. Creating a test route...');
      final newRoute = RouteDto(
        title: 'Test Route for is_public',
        description: 'Test route to validate is_public update',
        distanceM: 5000.0,
        estimatedDurationS: 1800,
        difficulty: 'MEDIUM',
        isPublic: false, // Start with private
        startPointLat: 41.0082,
        startPointLon: 28.9784,
        endPointLat: 41.0122,
        endPointLon: 28.9760,
        points: [
          RoutePointDto(seqNo: 0, latitude: 41.0082, longitude: 28.9784),
          RoutePointDto(seqNo: 1, latitude: 41.0102, longitude: 28.9772),
          RoutePointDto(seqNo: 2, latitude: 41.0122, longitude: 28.9760),
        ],
      );

      final createdRoute = await routeClient.createRoute(
        route: newRoute,
        accessToken: accessToken,
      );
      testRouteId = createdRoute.id;
      print('  ✓ Created test route with ID: $testRouteId');
      print('    Initial is_public: ${createdRoute.isPublic}');
    } else {
      // Use first available route
      testRouteId = routesResponse.content.first.id;
      print('  Found ${routesResponse.totalElements} routes');
      print('  Using route ID: $testRouteId');
      print('    Title: ${routesResponse.content.first.title}');
      print('    Current is_public: ${routesResponse.content.first.isPublic}');
    }
    print('');

    // Step 3: Get current route state before update
    print('Step 3: Getting route details before update...');
    final routeBefore = await routeClient.getRouteById(testRouteId!, accessToken: accessToken);
    print('  Route ID: ${routeBefore.id}');
    print('  Title: ${routeBefore.title}');
    print('  is_public (before): ${routeBefore.isPublic}');
    print('');

    // Step 4: Update route to set is_public = true using FULL update
    print('Step 4: Updating route - setting is_public to true...');
    print('  Testing with FULL route update (not partial)...');

    // Create a new RouteDto with the same data but isPublic = true
    // Note: Not including points as it may cause 500 error on backend
    final routeToUpdate = RouteDto(
      id: routeBefore.id,
      title: routeBefore.title,
      description: routeBefore.description,
      distanceM: routeBefore.distanceM,
      estimatedDurationS: routeBefore.estimatedDurationS,
      difficulty: routeBefore.difficulty,
      isPublic: true, // <-- Setting to true
      startPointLat: routeBefore.startPointLat,
      startPointLon: routeBefore.startPointLon,
      endPointLat: routeBefore.endPointLat,
      endPointLon: routeBefore.endPointLon,
      // points: routeBefore.points, // Omitting points
    );

    // Print the JSON being sent
    print('  Request body: ${routeToUpdate.toJson()}');

    final updatedRoute = await routeClient.updateRoute(
      routeId: testRouteId,
      route: routeToUpdate,
      accessToken: accessToken,
    );
    print('  ✓ Update request completed');
    print('  is_public (after update): ${updatedRoute.isPublic}');

    // Check if the issue is with the request or backend
    if (updatedRoute.isPublic != true) {
      print('');
      print('  ⚠️  BACKEND ISSUE DETECTED:');
      print('     Sent "public": true in request');
      print('     Backend returned "public": ${updatedRoute.isPublic}');
      print('     The backend may not be processing the "public" field in PUT /routes/{id}');
    }
    print('');

    // Step 5: Verify by fetching the route again
    print('Step 5: Verifying update by fetching route again...');
    final routeAfter = await routeClient.getRouteById(testRouteId, accessToken: accessToken);
    print('  is_public (verified): ${routeAfter.isPublic}');
    print('');

    // Step 6: Validate the update
    print('Step 6: Validation...');
    if (routeAfter.isPublic == true) {
      print('  ✓ SUCCESS: is_public is now true');
    } else {
      print('  ✗ FAILED: is_public is still ${routeAfter.isPublic}');
    }
    print('');

    // Step 7: Additional check - verify route appears in public routes
    print('Step 7: Checking if route appears in public routes...');
    final publicRoutes = await routeClient.getPublicRoutes(
      accessToken: accessToken,
      page: 0,
      size: 100,
    );
    final foundInPublic = publicRoutes.content.any((r) => r.id == testRouteId);
    if (foundInPublic) {
      print('  ✓ Route found in public routes list');
    } else {
      print('  ✗ Route NOT found in public routes list');
      print('    (This may be expected if filtering is applied)');
    }
    print('');

    // Step 8: Test setting is_public back to false
    print('Step 8: Testing reverse - setting is_public to false...');

    // Use full update to revert (without points)
    final routeToRevert = RouteDto(
      id: routeAfter.id,
      title: routeAfter.title,
      description: routeAfter.description,
      distanceM: routeAfter.distanceM,
      estimatedDurationS: routeAfter.estimatedDurationS,
      difficulty: routeAfter.difficulty,
      isPublic: false, // <-- Setting back to false
      startPointLat: routeAfter.startPointLat,
      startPointLon: routeAfter.startPointLon,
      endPointLat: routeAfter.endPointLat,
      endPointLon: routeAfter.endPointLon,
      // points: routeAfter.points, // Omitting points
    );

    final revertedRoute = await routeClient.updateRoute(
      routeId: testRouteId,
      route: routeToRevert,
      accessToken: accessToken,
    );
    print('  is_public (after revert): ${revertedRoute.isPublic}');

    if (revertedRoute.isPublic == false) {
      print('  ✓ Successfully reverted is_public to false');
    } else {
      print('  ✗ Failed to revert is_public');
    }
    print('');

    print('=== All tests completed! ===');

  } on DioException catch (e) {
    print('\n✗ API Error:');
    print('  Type: ${e.type}');
    print('  Message: ${e.message}');

    if (e.response != null) {
      print('  Status code: ${e.response?.statusCode}');
      print('  Response data: ${e.response?.data}');
    } else {
      print('  No response received.');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        print('  → Request timed out. Check server availability.');
      } else if (e.type == DioExceptionType.connectionError) {
        print('  → Make sure your backend server is running at $baseUrl');
      }
    }
  } on FormatException catch (e) {
    print('\n✗ Format Error:');
    print('  ${e.message}');
    print('  → Check if the API response matches the expected JSON structure');
  } catch (e) {
    print('\n✗ Unexpected Error:');
    print('  $e');
  }
}
