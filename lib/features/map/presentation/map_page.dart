import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../core/models/route.dart' as route_model;
import '../../../core/models/route_point.dart';
import '../../auth/data/auth_service.dart';
import '../data/route_repository.dart';
import '../data/route_naming_service.dart';

// Type alias to avoid conflict with Flutter's Route
typedef RunRoute = route_model.Route;

// Model for search suggestions
class SearchSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  SearchSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final RouteRepository _routeRepository = RouteRepository();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSearching = false;
  List<RunRoute> _nearbyRoutes = [];
  List<SearchSuggestion> _searchSuggestions = [];
  RunRoute? _selectedRoute;
  final Map<int, bool> _likedRoutes = {};
  final Map<int, int> _likeCounts = {};
  Timer? _debounceTimer;
  LatLng _currentCenter = const LatLng(41.085706, 29.001534); // Istanbul

  // Route creation mode
  bool _isCreatingRoute = false;
  LatLng? _pointA;
  LatLng? _pointB;
  List<LatLng> _waypoints = [];
  List<String> _waypointNames = []; // Names for waypoints
  RunRoute? _generatedRoute;
  bool _isGeneratingRoute = false;
  String? _pickingPointType; // 'start', 'end', or 'waypoint'
  String? _pointAName;
  String? _pointBName;

  // Starting location - Istanbul, Turkey
  static const LatLng _initialCenter = LatLng(41.085706, 29.001534);
  static const double _initialZoom = 13.0;

  @override
  void initState() {
    super.initState();
    // Load routes after a short delay to ensure map is rendered
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadNearbyRoutes();
      }
    });

    // Listen to search input changes
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Handle search input changes with debouncing
  void _onSearchChanged() {
    _debounceTimer?.cancel();

    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
      });
      return;
    }

    // Debounce search to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(_searchController.text);
    });
  }

  /// Search for places using Nominatim (OpenStreetMap) API
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
        ),
        headers: {
          'User-Agent': 'RunWithMeApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final suggestions = data
            .map((json) => SearchSuggestion.fromJson(json as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _searchSuggestions = suggestions;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Select a search suggestion and load routes
  Future<void> _selectSearchSuggestion(SearchSuggestion suggestion) async {
    final selectedPoint = LatLng(suggestion.lat, suggestion.lon);

    // Update search text and clear suggestions
    _searchController.text = suggestion.displayName.split(',').first;
    setState(() {
      _searchSuggestions = [];
      _currentCenter = selectedPoint;
    });

    // Unfocus search field
    _searchFocusNode.unfocus();

    // Move map to selected location
    _mapController.move(selectedPoint, 14.0);

    // If in creation mode, use the selected point for route planning
    if (_isCreatingRoute) {
      _handlePointSelection(selectedPoint);
    } else {
      // Load routes near the selected location
      await _loadRoutesAtLocation(suggestion.lat, suggestion.lon);
    }
  }

  /// Handle point selection for route creation (from search or tap)
  void _handlePointSelection(LatLng point) {
    setState(() {
      if (_pointA == null) {
        _pointA = point;
        _searchController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start point set. Now select end point.'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_pointB == null) {
        _pointB = point;
        _searchController.clear();
        // Generate route once both points are selected
        _generateRoute();
      } else {
        // If both points exist, this becomes a waypoint
        _waypoints.add(point);
        _searchController.clear();
        // Regenerate route with waypoints
        _generateRoute();
      }
    });
  }

  /// Load routes at a specific location
  Future<void> _loadRoutesAtLocation(double lat, double lon) async {
    setState(() {
      _isLoading = true;
    });

    final result = await _routeRepository.getNearbyRoutes(
      lat: lat,
      lon: lon,
      radius: 5000,
      size: 20,
      accessToken: _authService.accessToken,
    );

    if (result.success && result.routes != null) {
      // Fetch full route details to get all points for proper visualization
      final fullRoutes = await _routeRepository.fetchFullRouteDetails(
        routes: result.routes!,
        accessToken: _authService.accessToken,
      );

      if (mounted) {
        setState(() {
          _nearbyRoutes = fullRoutes;
          _isLoading = false;
        });

        // Load like status for each route
        for (var route in _nearbyRoutes) {
          _loadRouteLikeStatus(route.id);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Don't show error message for no routes found
    }
  }

  /// Get color for route based on index (for visual distinction)
  Color _getRouteColor(int index) {
    const colors = [
      Color(0xFF2196F3), // Blue
      Color(0xFF9C27B0), // Purple
      Color(0xFFFF9800), // Orange
      Color(0xFF00BCD4), // Cyan
      Color(0xFFE91E63), // Pink
    ];
    return colors[index % colors.length];
  }

  /// Load nearby routes based on current center
  Future<void> _loadNearbyRoutes() async {
    await _loadRoutesAtLocation(_currentCenter.latitude, _currentCenter.longitude);
  }

  /// Load like status and count for a route
  Future<void> _loadRouteLikeStatus(int routeId) async {
    if (_authService.accessToken == null) return;

    // Check if liked
    final isLiked = await _routeRepository.checkIfLiked(
      routeId: routeId,
      accessToken: _authService.accessToken!,
    );

    // Get like count
    final count = await _routeRepository.getLikeCount(
      routeId: routeId,
      accessToken: _authService.accessToken,
    );

    if (mounted) {
      setState(() {
        _likedRoutes[routeId] = isLiked;
        _likeCounts[routeId] = count;
      });
    }
  }

  /// Toggle route creation mode
  void _toggleCreateMode() {
    setState(() {
      _isCreatingRoute = !_isCreatingRoute;
      if (!_isCreatingRoute) {
        // Clear creation state when exiting mode
        _pointA = null;
        _pointB = null;
        _waypoints = [];
        _waypointNames = [];
        _generatedRoute = null;
        _pickingPointType = null;
        _pointAName = null;
        _pointBName = null;
      }
    });
  }

  /// Handle map tap in creation mode
  void _handleMapTap(LatLng point) {
    if (!_isCreatingRoute) return;

    // Handle pick on map mode
    if (_pickingPointType != null) {
      _setPointWithReverseGeocode(point, _pickingPointType!);
      return;
    }

    // Default behavior for old tap-to-select
    _handlePointSelection(point);
  }

  /// Set a point and fetch its location name via reverse geocoding
  Future<void> _setPointWithReverseGeocode(LatLng point, String pointType) async {
    // Set point immediately with loading placeholder
    setState(() {
      if (pointType == 'start') {
        _pointA = point;
        _pointAName = 'Loading...';
      } else if (pointType == 'end') {
        _pointB = point;
        _pointBName = 'Loading...';
      } else if (pointType == 'waypoint') {
        // When adding a waypoint, the current endpoint becomes a waypoint
        // and the new point becomes the new endpoint
        if (_pointB != null && _pointBName != null) {
          _waypoints.add(_pointB!);
          _waypointNames.add(_pointBName!);
        }
        _pointB = point;
        _pointBName = 'Loading...';
      }
      _pickingPointType = null;
    });

    // Fetch location name asynchronously
    final locationName = await RouteNamingService.getLocationDisplayName(point);
    if (mounted) {
      setState(() {
        if (pointType == 'start') {
          _pointAName = locationName;
        } else {
          // Both 'end' and 'waypoint' update pointB
          _pointBName = locationName;
        }
      });
    }

    // Generate route if both points are set
    if (_pointA != null && _pointB != null) {
      _generateRoute();
    }
  }

  /// Generate route using OSRM API
  Future<void> _generateRoute() async {
    if (_pointA == null || _pointB == null) return;

    setState(() {
      _isGeneratingRoute = true;
    });

    try {
      // Build coordinates string with waypoints
      var coordinates = '${_pointA!.longitude},${_pointA!.latitude}';

      // Add waypoints if any
      for (var waypoint in _waypoints) {
        coordinates += ';${waypoint.longitude},${waypoint.latitude}';
      }

      // Add end point
      coordinates += ';${_pointB!.longitude},${_pointB!.latitude}';

      // Use OSRM (Open Source Routing Machine) for foot routing
      // continue_straight=true prevents waypoint reordering
      final url = 'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
          '$coordinates'
          '?overview=full&geometries=geojson&steps=true&continue_straight=true';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RunWithMeApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;
          final distance = route['distance'] as num; // in meters
          final duration = route['duration'] as num; // in seconds

          // Convert coordinates to RoutePoint list
          final points = coordinates.asMap().entries.map((entry) {
            final coord = entry.value as List;
            return RoutePoint(
              pointId: 0, // Temporary, will be assigned by backend
              routeId: 0, // Temporary
              seqNo: entry.key,
              latitude: (coord[1] as num).toDouble(),
              longitude: (coord[0] as num).toDouble(),
              elevationM: null,
            );
          }).toList();

          // Generate route title from point names
          final startName = _pointAName ?? 'Start';
          final endName = _pointBName ?? 'End';
          // If both names are the same, use "Route in X" format
          final routeTitle = (startName == endName || startName == 'Unknown Location' || endName == 'Unknown Location')
              ? 'Route in ${startName != 'Unknown Location' ? startName : endName}'
              : '$startName - $endName';

          // Create a temporary route object
          setState(() {
            _generatedRoute = route_model.Route(
              id: 0, // Temporary, will be assigned by backend
              title: routeTitle,
              description: 'Route from $startName to $endName',
              distanceM: distance.toDouble(),
              estimatedDurationS: duration.toInt(),
              points: points,
              startPointLat: _pointA!.latitude,
              startPointLon: _pointA!.longitude,
              endPointLat: _pointB!.latitude,
              endPointLon: _pointB!.longitude,
              difficulty: _calculateDifficulty(distance.toDouble()),
              isPublic: true,
              creatorId: null, // Will be set when saving
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _isGeneratingRoute = false;
          });

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Route generated! Tap the save button to add it to your routes.')),
            );
          }
        } else {
          throw Exception('No route found');
        }
      } else {
        throw Exception('Failed to generate route');
      }
    } catch (e) {
      setState(() {
        _isGeneratingRoute = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate route: $e')),
        );
      }
    }
  }

  /// Calculate difficulty based on distance
  String _calculateDifficulty(double distanceM) {
    final distanceKm = distanceM / 1000;
    if (distanceKm < 2) return 'Easy';
    if (distanceKm < 5) return 'Medium';
    if (distanceKm < 10) return 'Hard';
    return 'Very Hard';
  }

  /// Save generated route to database
  Future<void> _saveGeneratedRoute() async {
    if (_generatedRoute == null) return;

    if (_authService.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save routes')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _routeRepository.createRoute(
      route: _generatedRoute!,
      accessToken: _authService.accessToken!,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.success && result.route != null) {
      // Automatically like the route so it appears in saved routes
      final createdRoute = result.route!;
      try {
        await _routeRepository.likeRoute(
          routeId: createdRoute.id,
          accessToken: _authService.accessToken!,
        );
      } catch (_) {
        // Silently ignore auto-like failures
      }

      // Exit creation mode
      setState(() {
        _isCreatingRoute = false;
        _pointA = null;
        _pointB = null;
        _waypoints = [];
        _waypointNames = [];
        _generatedRoute = null;
        _pickingPointType = null;
        _pointAName = null;
        _pointBName = null;
      });

      // Refresh nearby routes
      await _loadNearbyRoutes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route saved successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to save route')),
        );
      }
    }
  }

  /// Toggle like/unlike for a route
  Future<void> _toggleLike(RunRoute route) async {
    if (_authService.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like routes')),
      );
      return;
    }

    final isCurrentlyLiked = _likedRoutes[route.id] ?? false;

    // Optimistic update
    setState(() {
      _likedRoutes[route.id] = !isCurrentlyLiked;
      _likeCounts[route.id] = (_likeCounts[route.id] ?? 0) + (isCurrentlyLiked ? -1 : 1);
    });

    final result = isCurrentlyLiked
        ? await _routeRepository.unlikeRoute(
            routeId: route.id,
            accessToken: _authService.accessToken!,
          )
        : await _routeRepository.likeRoute(
            routeId: route.id,
            accessToken: _authService.accessToken!,
          );

    if (!result.success) {
      // Revert on failure
      setState(() {
        _likedRoutes[route.id] = isCurrentlyLiked;
        _likeCounts[route.id] = (_likeCounts[route.id] ?? 0) + (isCurrentlyLiked ? 1 : -1);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to update like')),
        );
      }
    }
  }

  /// Select a route and show details
  void _selectRoute(RunRoute route) {
    setState(() {
      _selectedRoute = route;
    });

    // Center map on route
    _mapController.move(
      LatLng(route.startPointLat, route.startPointLon),
      15.0,
    );

    // Show route details bottom sheet
    _showRouteDetails(route);
  }

  /// Show route details in bottom sheet
  void _showRouteDetails(RunRoute route) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      route.title ?? 'Unnamed Route',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stats
                    Row(
                      children: [
                        _buildStat(Icons.straighten, route.formattedDistance),
                        const SizedBox(width: 20),
                        _buildStat(Icons.timer, route.formattedDuration),
                        const SizedBox(width: 20),
                        if (route.difficulty != null)
                          _buildStat(Icons.trending_up, route.difficulty!),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Description
                    if (route.description != null) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        route.description!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Like button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleLike(route),
                        icon: Icon(
                          _likedRoutes[route.id] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: Text(
                          _likedRoutes[route.id] == true
                              ? 'Unlike (${_likeCounts[route.id] ?? 0})'
                              : 'Like Route (${_likeCounts[route.id] ?? 0})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _likedRoutes[route.id] == true
                              ? Colors.red
                              : const Color(0xFF7ED321),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ],
    );
  }

  /// Build Google Maps-style route creation view
  Widget _buildRouteCreationView() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleCreateMode,
        ),
        title: const Text('Create Route'),
        actions: [
          if (_generatedRoute != null)
            TextButton(
              onPressed: _isLoading ? null : _saveGeneratedRoute,
              child: Text(
                'DONE',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : const Color(0xFF7ED321),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Points list
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Point A (Start)
                _buildPointRow(
                  label: null,
                  hint: 'Choose starting location',
                  icon: Icons.my_location,
                  value: _pointA,
                  displayName: _pointAName,
                  onTap: () => _showPointSelectionOptions(isStartPoint: true),
                  onClear: () {
                    setState(() {
                      _pointA = null;
                      _pointAName = null;
                      _generatedRoute = null;
                    });
                  },
                ),
                const Divider(height: 1),

                // Point B (End)
                _buildPointRow(
                  label: 'B',
                  hint: 'Choose destination',
                  icon: Icons.location_on,
                  value: _pointB,
                  displayName: _pointBName,
                  onTap: () => _showPointSelectionOptions(isStartPoint: false),
                  onClear: () {
                    setState(() {
                      _pointB = null;
                      _pointBName = null;
                      _generatedRoute = null;
                    });
                  },
                ),

                // Waypoints
                ..._waypoints.asMap().entries.map((entry) {
                  return Column(
                    children: [
                      const Divider(height: 1),
                      _buildPointRow(
                        label: String.fromCharCode(67 + entry.key), // C, D, E, etc.
                        hint: 'Stop ${entry.key + 1}',
                        icon: Icons.add_location,
                        value: entry.value,
                        displayName: entry.key < _waypointNames.length ? _waypointNames[entry.key] : null,
                        onTap: () => _showPointSelectionOptions(isStartPoint: false, isWaypoint: true),
                        onClear: () {
                          setState(() {
                            _waypoints.removeAt(entry.key);
                            if (entry.key < _waypointNames.length) {
                              _waypointNames.removeAt(entry.key);
                            }
                            _generateRoute();
                          });
                        },
                      ),
                    ],
                  );
                }),

                // Add stop button
                if (_pointA != null && _pointB != null)
                  Column(
                    children: [
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF5F5F5),
                          child: Icon(Icons.add, color: Colors.black87),
                        ),
                        title: const Text('Add stop'),
                        onTap: () => _showPointSelectionOptions(isStartPoint: false, isWaypoint: true),
                      ),
                    ],
                  ),

                // Total trip duration
                if (_generatedRoute != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFF8F8F8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total trip: ${_generatedRoute!.formattedDuration}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _generatedRoute!.formattedDistance,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pointA ?? _initialCenter,
                initialZoom: _initialZoom,
                minZoom: 3.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (tapPosition, point) => _handleMapTap(point),
              ),
              children: [
                // OpenStreetMap tile layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.runwithme_app',
                  maxZoom: 19,
                ),

                // Generated route polyline
                if (_generatedRoute != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _generatedRoute!.points
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        strokeWidth: 5.0,
                        color: const Color(0xFF7ED321),
                      ),
                    ],
                  ),

                // Markers
                MarkerLayer(
                  markers: [
                    if (_pointA != null)
                      Marker(
                        point: _pointA!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Waypoint markers
                    ..._waypoints.asMap().entries.map((entry) {
                      return Marker(
                        point: entry.value,
                        width: 35,
                        height: 35,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(67 + entry.key), // C, D, E
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_pointB != null)
                      Marker(
                        point: _pointB!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Center(
                            child: Text(
                              'B',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isGeneratingRoute)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// Build a point row for route creation
  Widget _buildPointRow({
    required String? label,
    required String hint,
    required IconData icon,
    required LatLng? value,
    String? displayName,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF5F5F5),
        child: label != null
            ? Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              )
            : Icon(icon, color: Colors.black87),
      ),
      title: Text(
        value != null
            ? (displayName ?? '${value.latitude.toStringAsFixed(4)}, ${value.longitude.toStringAsFixed(4)}')
            : hint,
        style: TextStyle(
          color: value != null ? Colors.black87 : Colors.grey[600],
          fontSize: 16,
        ),
      ),
      trailing: value != null
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClear,
            )
          : const Icon(Icons.search),
      onTap: onTap,
    );
  }

  /// Show search dialog for point selection
  void _showPointSearch({bool isStartPoint = false, bool isWaypoint = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchSuggestions = [];
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        _onSearchChanged();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search results
                  Expanded(
                    child: _isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : _searchSuggestions.isEmpty
                            ? Center(
                                child: Text(
                                  'Search for a location',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _searchSuggestions.length,
                                itemBuilder: (context, index) {
                                  final suggestion = _searchSuggestions[index];
                                  return ListTile(
                                    leading: const Icon(Icons.location_on),
                                    title: Text(
                                      suggestion.displayName.split(',').first,
                                    ),
                                    subtitle: Text(
                                      suggestion.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      final point = LatLng(suggestion.lat, suggestion.lon);
                                      final locationName = suggestion.displayName.split(',').first.trim();

                                      setState(() {
                                        if (isStartPoint) {
                                          _pointA = point;
                                          _pointAName = locationName;
                                        } else if (isWaypoint) {
                                          // When adding a waypoint, the current endpoint becomes a waypoint
                                          // and the new point becomes the new endpoint
                                          if (_pointB != null && _pointBName != null) {
                                            _waypoints.add(_pointB!);
                                            _waypointNames.add(_pointBName!);
                                          }
                                          _pointB = point;
                                          _pointBName = locationName;
                                        } else {
                                          _pointB = point;
                                          _pointBName = locationName;
                                        }
                                        _searchController.clear();
                                        _searchSuggestions = [];
                                      });

                                      // Move map to selected location
                                      _mapController.move(point, 14.0);

                                      // Generate route if both points are set
                                      if (_pointA != null && _pointB != null) {
                                        _generateRoute();
                                      }
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Show point selection options
  void _showPointSelectionOptions({
    required bool isStartPoint,
    bool isWaypoint = false,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isStartPoint) ...[
                ListTile(
                  leading: const Icon(Icons.my_location, color: Color(0xFF7ED321)),
                  title: const Text('Use Your Location'),
                  onTap: () {
                    Navigator.pop(context);
                    _useCurrentLocation();
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.search, color: Color(0xFF7ED321)),
                title: const Text('Search Location'),
                onTap: () {
                  Navigator.pop(context);
                  _showPointSearch(
                    isStartPoint: isStartPoint,
                    isWaypoint: isWaypoint,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.pin_drop, color: Color(0xFF7ED321)),
                title: const Text('Pick on Map'),
                onTap: () {
                  Navigator.pop(context);
                  _pickOnMap(isStartPoint: isStartPoint, isWaypoint: isWaypoint);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Use current location as starting point
  Future<void> _useCurrentLocation() async {
    try {
      // Move map to current center and use it as starting point
      final currentLocation = _mapController.camera.center;

      setState(() {
        _pointA = currentLocation;
        _pointAName = 'Loading...';
      });

      // Move map to this location
      _mapController.move(currentLocation, 14.0);

      // Fetch location name via reverse geocoding
      final locationName = await RouteNamingService.getLocationDisplayName(currentLocation);
      if (mounted) {
        setState(() {
          _pointAName = locationName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start point set to $locationName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  /// Pick point on map
  void _pickOnMap({required bool isStartPoint, bool isWaypoint = false}) {
    setState(() {
      _pickingPointType = isStartPoint ? 'start' : isWaypoint ? 'waypoint' : 'end';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isStartPoint
              ? 'Tap on the map to set start point'
              : isWaypoint
                  ? 'Tap on the map to add waypoint'
                  : 'Tap on the map to set destination',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreatingRoute) {
      return _buildRouteCreationView();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              minZoom: 3.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) => _handleMapTap(point),
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.runwithme_app',
                maxZoom: 19,
                subdomains: const ['a', 'b', 'c'],
              ),

              // Route polylines (existing routes from database)
              if (_nearbyRoutes.isNotEmpty && !_isCreatingRoute)
                PolylineLayer(
                  polylines: _nearbyRoutes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final route = entry.value;
                    // Use route points if available, otherwise draw line from start to end
                    final points = route.points.isNotEmpty
                        ? route.points.map((p) => LatLng(p.latitude, p.longitude)).toList()
                        : [
                            LatLng(route.startPointLat, route.startPointLon),
                            LatLng(route.endPointLat, route.endPointLon),
                          ];
                    return Polyline(
                      points: points,
                      strokeWidth: route.id == _selectedRoute?.id ? 6.0 : 4.0,
                      color: route.id == _selectedRoute?.id
                          ? const Color(0xFF7ED321)
                          : _getRouteColor(index),
                    );
                  }).toList(),
                ),

              // Generated route polyline (new route being created)
              if (_generatedRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _generatedRoute!.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                      strokeWidth: 5.0,
                      color: const Color(0xFF7ED321),
                    ),
                  ],
                ),

              // Start/End markers for existing routes
              if (_nearbyRoutes.isNotEmpty && !_isCreatingRoute)
                MarkerLayer(
                  markers: _nearbyRoutes.expand((route) {
                    return [
                      // Start marker
                      Marker(
                        point: LatLng(route.startPointLat, route.startPointLon),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () => _selectRoute(route),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      // End marker
                      Marker(
                        point: LatLng(route.endPointLat, route.endPointLon),
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () => _selectRoute(route),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.stop, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ];
                  }).toList(),
                ),

              // Point A and B markers for route creation
              if (_isCreatingRoute)
                MarkerLayer(
                  markers: [
                    if (_pointA != null)
                      Marker(
                        point: _pointA!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Waypoint markers
                    ..._waypoints.asMap().entries.map((entry) {
                      return Marker(
                        point: entry.value,
                        width: 35,
                        height: 35,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_pointB != null)
                      Marker(
                        point: _pointB!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Center(
                            child: Text(
                              'B',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),

          // Search bar with autocomplete
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Search input
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey[400]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Search for a place...',
                                    border: InputBorder.none,
                                    hintStyle: TextStyle(color: Colors.grey[400]),
                                  ),
                                ),
                              ),
                              if (_isSearching)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchSuggestions = [];
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),

                        // Search suggestions
                        if (_searchSuggestions.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchSuggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _searchSuggestions[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on, size: 20),
                                  title: Text(
                                    suggestion.displayName,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectSearchSuggestion(suggestion),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls (zoom, create route, etc.)
          Positioned(
            right: 16,
            top: 100,
            child: SafeArea(
              child: Column(
                children: [
                  // Create Route button
                  FloatingActionButton.small(
                    heroTag: 'create_route',
                    backgroundColor: _isCreatingRoute ? const Color(0xFF7ED321) : Colors.white,
                    onPressed: _toggleCreateMode,
                    child: Icon(
                      _isCreatingRoute ? Icons.close : Icons.add_road,
                      color: _isCreatingRoute ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                    child: const Icon(Icons.add, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                    child: const Icon(Icons.remove, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'my_location',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.move(_initialCenter, _initialZoom);
                    },
                    child: const Icon(Icons.my_location, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'refresh',
                    backgroundColor: Colors.white,
                    onPressed: _loadNearbyRoutes,
                    child: const Icon(Icons.refresh, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // Route creation instructions or generated route info
          if (_isCreatingRoute)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
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
                child: _generatedRoute != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Generated Route',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(_generatedRoute!.formattedDistance),
                                        const SizedBox(width: 16),
                                        Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(_generatedRoute!.formattedDuration),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveGeneratedRoute,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_isLoading ? 'Saving...' : 'Save Route'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7ED321),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _pointA == null
                                ? Icons.looks_one
                                : _pointB == null
                                    ? Icons.looks_two
                                    : Icons.add_location,
                            size: 40,
                            color: const Color(0xFF7ED321),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _pointA == null
                                ? 'Search or tap on the map\nto set start point (A)'
                                : _pointB == null
                                    ? 'Search or tap on the map\nto set end point (B)'
                                    : 'Tap "Add Stop" or search\nto add waypoints',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_isGeneratingRoute)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
              ),
            ),

          // Route list at bottom (when not creating)
          if (_nearbyRoutes.isNotEmpty && !_isCreatingRoute)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyRoutes.length,
                  itemBuilder: (context, index) {
                    return _buildRouteCard(_nearbyRoutes[index]);
                  },
                ),
              ),
            ),

          // Loading indicator
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

  Widget _buildRouteCard(RunRoute route) {
    final isLiked = _likedRoutes[route.id] ?? false;
    final likeCount = _likeCounts[route.id] ?? 0;

    return GestureDetector(
      onTap: () => _selectRoute(route),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: route.id == _selectedRoute?.id
              ? Border.all(color: const Color(0xFF7ED321), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              route.title ?? 'Unnamed Route',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Stats
            Row(
              children: [
                Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  route.formattedDistance,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    route.formattedDuration,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Difficulty
            if (route.difficulty != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7ED321).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  route.difficulty!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7ED321),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Spacer(),

            // Like button
            Row(
              children: [
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: isLiked ? Colors.red : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '$likeCount',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
