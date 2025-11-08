import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MapTestApp());
}

class MapTestApp extends StatelessWidget {
  const MapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenStreetMap Navigation',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const OpenStreetMapPage(),
    );
  }
}

class OpenStreetMapPage extends StatefulWidget {
  const OpenStreetMapPage({super.key});

  @override
  State<OpenStreetMapPage> createState() => _OpenStreetMapPageState();
}

class _OpenStreetMapPageState extends State<OpenStreetMapPage> {
  final MapController _mapController = MapController();
  
  // Starting location - Istanbul, Turkey (change to your location)
  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);
  static const double _initialZoom = 13.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenStreetMap Navigation'),
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'home',
            onPressed: () {
              _mapController.move(_initialCenter, _initialZoom);
            },
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: _initialZoom,
          minZoom: 3.0,
          maxZoom: 18.0,
          // Enable all gestures
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
          // Rich attribution layer (OpenStreetMap requires attribution)
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => null, // You can add a link to OSM here
              ),
            ],
          ),
        ],
      ),
    );
  }
}