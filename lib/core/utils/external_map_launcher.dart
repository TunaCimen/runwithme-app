import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enum representing available map applications
enum MapApp {
  googleMaps('Google Maps', 'google_maps'),
  appleMaps('Apple Maps', 'apple_maps'),
  yandexMaps('Yandex Maps', 'yandex_maps'),
  yandexNavi('Yandex Navigator', 'yandex_navi');

  final String displayName;
  final String id;

  const MapApp(this.displayName, this.id);
}

/// Utility class for launching external map applications
class ExternalMapLauncher {
  /// Get list of available map apps on the current platform
  static List<MapApp> getAvailableMapApps() {
    if (Platform.isIOS) {
      return [
        MapApp.appleMaps,
        MapApp.googleMaps,
        MapApp.yandexMaps,
        MapApp.yandexNavi,
      ];
    } else if (Platform.isAndroid) {
      return [
        MapApp.googleMaps,
        MapApp.yandexMaps,
        MapApp.yandexNavi,
      ];
    }
    return [MapApp.googleMaps];
  }

  /// Build the URL for navigating to a location using the specified map app
  static Uri _buildNavigationUrl(
    MapApp mapApp,
    double latitude,
    double longitude,
  ) {
    switch (mapApp) {
      case MapApp.googleMaps:
        // Google Maps navigation URL
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking',
        );

      case MapApp.appleMaps:
        // Apple Maps URL
        return Uri.parse(
          'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=w',
        );

      case MapApp.yandexMaps:
        // Yandex Maps URL
        return Uri.parse(
          'yandexmaps://maps.yandex.com/?rtext=~$latitude,$longitude&rtt=pd',
        );

      case MapApp.yandexNavi:
        // Yandex Navigator URL
        return Uri.parse(
          'yandexnavi://build_route_on_map?lat_to=$latitude&lon_to=$longitude',
        );
    }
  }

  /// Build a fallback web URL for map apps
  static Uri _buildFallbackUrl(
    MapApp mapApp,
    double latitude,
    double longitude,
  ) {
    switch (mapApp) {
      case MapApp.googleMaps:
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking',
        );

      case MapApp.appleMaps:
        return Uri.parse(
          'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=w',
        );

      case MapApp.yandexMaps:
      case MapApp.yandexNavi:
        return Uri.parse(
          'https://yandex.com/maps/?rtext=~$latitude,$longitude&rtt=pd',
        );
    }
  }

  /// Launch navigation to the specified coordinates using the selected map app
  static Future<bool> launchNavigation({
    required MapApp mapApp,
    required double latitude,
    required double longitude,
  }) async {
    final url = _buildNavigationUrl(mapApp, latitude, longitude);

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Try fallback URL for web-based navigation
        final fallbackUrl = _buildFallbackUrl(mapApp, latitude, longitude);
        return await launchUrl(
          fallbackUrl,
          mode: LaunchMode.externalApplication,
        );
      }

      return launched;
    } catch (e) {
      debugPrint('[ExternalMapLauncher] Error launching map app: $e');

      // Try fallback URL
      try {
        final fallbackUrl = _buildFallbackUrl(mapApp, latitude, longitude);
        return await launchUrl(
          fallbackUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('[ExternalMapLauncher] Fallback also failed: $e');
        return false;
      }
    }
  }

  /// Show a dialog to let the user pick which map app to use
  static Future<MapApp?> showMapAppPicker(BuildContext context) async {
    final availableApps = getAvailableMapApps();

    return showModalBottomSheet<MapApp>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Open with',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...availableApps.map((app) => ListTile(
                      leading: _getMapAppIcon(app),
                      title: Text(app.displayName),
                      onTap: () => Navigator.pop(context, app),
                    )),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get the icon for a map app
  static Widget _getMapAppIcon(MapApp mapApp) {
    IconData iconData;
    Color iconColor;

    switch (mapApp) {
      case MapApp.googleMaps:
        iconData = Icons.map;
        iconColor = Colors.green;
        break;
      case MapApp.appleMaps:
        iconData = Icons.map_outlined;
        iconColor = Colors.blue;
        break;
      case MapApp.yandexMaps:
        iconData = Icons.explore;
        iconColor = Colors.red;
        break;
      case MapApp.yandexNavi:
        iconData = Icons.navigation;
        iconColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }
}
