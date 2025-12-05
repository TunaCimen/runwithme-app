import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

/// Service for generating meaningful route names based on start and end locations.
/// Uses reverse geocoding to get the smallest locality unit (village, town, neighborhood).
class RouteNamingService {
  /// Generates a route name based on start and end coordinates.
  ///
  /// Returns names like:
  /// - "Beşiktaş - Kadıköy" (different locations)
  /// - "Route in Beşiktaş" (same location)
  /// - "Run on [date]" (fallback if geocoding fails)
  static Future<String> generateRouteName(LatLng start, LatLng end) async {
    try {
      var startName = await _getLocationName(start);
      var endName = await _getLocationName(end);

      if (startName == null && endName == null) {
        return _getFallbackName();
      }

      if (startName == null) {
        return 'Route in $endName';
      }

      if (endName == null) {
        return 'Route in $startName';
      }

      if (startName == endName) {
        return 'Route in $startName';
      }

      return '$startName - $endName';
    } catch (e) {
      return _getFallbackName();
    }
  }

  /// Gets the smallest locality name from coordinates.
  /// Prioritizes: subLocality > locality > subAdministrativeArea > administrativeArea
  static Future<String?> _getLocationName(LatLng point) async {
    try {
      var placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isEmpty) {
        return null;
      }

      var placemark = placemarks.first;

      // Try to get the smallest locality unit available
      // Priority: neighborhood/subLocality > town/locality > district > city
      var name = placemark.subLocality;
      if (name != null && name.isNotEmpty) {
        return name;
      }

      name = placemark.locality;
      if (name != null && name.isNotEmpty) {
        return name;
      }

      name = placemark.subAdministrativeArea;
      if (name != null && name.isNotEmpty) {
        return name;
      }

      name = placemark.administrativeArea;
      if (name != null && name.isNotEmpty) {
        return name;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generates a fallback name using current date
  static String _getFallbackName() {
    var now = DateTime.now();
    var month = _getMonthName(now.month);
    return 'Run on $month ${now.day}';
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Gets a single location name for display (e.g., for current position)
  static Future<String> getLocationDisplayName(LatLng point) async {
    var name = await _getLocationName(point);
    return name ?? 'Unknown Location';
  }
}
