import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  bool _isTracking = false;
  String _currentDistance = '0.0';
  String _currentPace = '0:00';
  String _currentDuration = '00:00';

  // Starting location - Istanbul, Turkey (change to your location)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 13.0;

  // Mock nearby runners
  final List<NearbyRunner> _nearbyRunners = [
    NearbyRunner(
      username: 'johndoe',
      fullName: 'John Doe',
      distance: 0.5,
      location: const LatLng(41.0092, 28.9794),
    ),
    NearbyRunner(
      username: 'sarahrunner',
      fullName: 'Sarah Runner',
      distance: 1.2,
      location: const LatLng(41.0072, 28.9774),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // OpenStreetMap
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
            ),
            children: [
              // OpenStreetMap tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.runwithme_app',
                maxZoom: 19,
                subdomains: const ['a', 'b', 'c'],
              ),
              // Markers for nearby runners
              MarkerLayer(
                markers: _nearbyRunners.map((runner) {
                  return Marker(
                    point: runner.location,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF7ED321),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          runner.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Top bar with search and filters
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search for running partners...',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () {
                        _showFilterSheet();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            right: 16,
            top: 100,
            child: SafeArea(
              child: Column(
                children: [
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
                ],
              ),
            ),
          ),

          // Nearby runners list
          if (!_isTracking)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _nearbyRunners.length,
                  itemBuilder: (context, index) {
                    return _buildNearbyRunnerCard(_nearbyRunners[index]);
                  },
                ),
              ),
            ),

          // Run tracking stats (when active)
          if (_isTracking)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTrackingStat('Distance', '$_currentDistance km'),
                        _buildTrackingStat('Pace', '$_currentPace /km'),
                        _buildTrackingStat('Duration', _currentDuration),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Start/Stop tracking button
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                onPressed: _toggleTracking,
                backgroundColor: _isTracking ? Colors.red : const Color(0xFF7ED321),
                child: Icon(
                  _isTracking ? Icons.stop : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
      if (!_isTracking) {
        // Reset stats when stopping
        _currentDistance = '0.0';
        _currentPace = '0:00';
        _currentDuration = '00:00';
      }
    });
  }

  Widget _buildNearbyRunnerCard(NearbyRunner runner) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF7ED321).withValues(alpha: 0.2),
            child: Text(
              runner.fullName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7ED321),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            runner.fullName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${runner.distance} km away',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.route),
                title: const Text('Show Routes'),
                trailing: Switch(
                  value: true,
                  onChanged: (val) {},
                  activeColor: const Color(0xFF7ED321),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Show Nearby Runners'),
                trailing: Switch(
                  value: true,
                  onChanged: (val) {},
                  activeColor: const Color(0xFF7ED321),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// Nearby runner model
class NearbyRunner {
  final String username;
  final String fullName;
  final double distance;
  final LatLng location;

  NearbyRunner({
    required this.username,
    required this.fullName,
    required this.distance,
    required this.location,
  });
}
