import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

/// Service for generating meaningful run session names based on time and location.
/// Uses reverse geocoding to get the smallest locality unit (village, town, neighborhood).
class RunNamingService {
  // Cache for location names to avoid repeated geocoding calls
  static final Map<String, String> _locationCache = {};

  /// Generates a run name based on start time and coordinates.
  ///
  /// Returns names like:
  /// - "Morning Run in Bebek" (same start/end location)
  /// - "Afternoon Run from Celiktepe to Bebek" (different locations)
  /// - "Evening Run" (fallback if no coordinates)
  /// - "Night Run on Dec 21" (fallback if geocoding fails)
  static Future<String> generateRunName({
    required DateTime startTime,
    LatLng? startPoint,
    LatLng? endPoint,
  }) async {
    final timePrefix = _getTimeOfDayPrefix(startTime);

    // If no coordinates available, return simple time-based name
    if (startPoint == null && endPoint == null) {
      return timePrefix;
    }

    try {
      String? startName;
      String? endName;

      if (startPoint != null) {
        startName = await _getLocationName(startPoint);
      }

      if (endPoint != null) {
        endName = await _getLocationName(endPoint);
      }

      // Both locations failed
      if (startName == null && endName == null) {
        return _getFallbackName(timePrefix, startTime);
      }

      // Only end location available
      if (startName == null) {
        return '$timePrefix in $endName';
      }

      // Only start location available
      if (endName == null) {
        return '$timePrefix in $startName';
      }

      // Same location (circular route or close proximity)
      if (startName == endName) {
        return '$timePrefix in $startName';
      }

      // Different locations
      return '$timePrefix from $startName to $endName';
    } catch (e) {
      return _getFallbackName(timePrefix, startTime);
    }
  }

  /// Gets the time-of-day prefix based on the hour.
  static String _getTimeOfDayPrefix(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) {
      return 'Morning Run';
    } else if (hour >= 12 && hour < 17) {
      return 'Afternoon Run';
    } else if (hour >= 17 && hour < 21) {
      return 'Evening Run';
    } else {
      return 'Night Run';
    }
  }

  /// Gets the smallest locality name from coordinates.
  /// Uses caching to avoid repeated geocoding calls.
  /// Prioritizes: subLocality > locality > subAdministrativeArea > administrativeArea
  static Future<String?> _getLocationName(LatLng point) async {
    // Create cache key with reduced precision to group nearby points
    final cacheKey =
        '${point.latitude.toStringAsFixed(3)},${point.longitude.toStringAsFixed(3)}';

    if (_locationCache.containsKey(cacheKey)) {
      return _locationCache[cacheKey];
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;

      // Try to get the smallest locality unit available
      // Priority: neighborhood/subLocality > town/locality > district > city
      String? name = placemark.subLocality;
      if (name != null && name.isNotEmpty) {
        _locationCache[cacheKey] = name;
        return name;
      }

      name = placemark.locality;
      if (name != null && name.isNotEmpty) {
        _locationCache[cacheKey] = name;
        return name;
      }

      name = placemark.subAdministrativeArea;
      if (name != null && name.isNotEmpty) {
        _locationCache[cacheKey] = name;
        return name;
      }

      name = placemark.administrativeArea;
      if (name != null && name.isNotEmpty) {
        _locationCache[cacheKey] = name;
        return name;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generates a fallback name using the date
  static String _getFallbackName(String timePrefix, DateTime startTime) {
    final month = _getMonthName(startTime.month);
    return '$timePrefix on $month ${startTime.day}';
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  /// Gets a single location name for display
  static Future<String> getLocationDisplayName(LatLng point) async {
    final name = await _getLocationName(point);
    return name ?? 'Unknown Location';
  }

  /// Clears the location cache (useful for testing or memory management)
  static void clearCache() {
    _locationCache.clear();
  }
}
