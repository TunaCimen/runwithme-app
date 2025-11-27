// Barrel export for location models
export 'region.dart';
export 'subregion.dart';
export 'country.dart';
export 'state.dart';
export 'city.dart';

import 'region.dart';
import 'subregion.dart';
import 'country.dart';
import 'state.dart';
import 'city.dart';

/// Complete location data combining all location hierarchy levels
class Location {
  final Region? region;
  final Subregion? subregion;
  final Country? country;
  final State? state;
  final City? city;

  const Location({
    this.region,
    this.subregion,
    this.country,
    this.state,
    this.city,
  });

  /// Returns a formatted location string (e.g., "New York, NY, USA")
  String get displayName {
    final parts = <String>[];
    if (city != null) parts.add(city!.name);
    if (state != null) parts.add(state!.name);
    if (country != null) parts.add(country!.name);
    return parts.join(', ');
  }

  /// Returns a short location string (e.g., "New York, USA")
  String get shortDisplayName {
    final parts = <String>[];
    if (city != null) parts.add(city!.name);
    if (country != null) parts.add(country!.name);
    return parts.join(', ');
  }

  @override
  String toString() {
    return 'Location($displayName)';
  }

  Location copyWith({
    Region? region,
    Subregion? subregion,
    Country? country,
    State? state,
    City? city,
  }) {
    return Location(
      region: region ?? this.region,
      subregion: subregion ?? this.subregion,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
    );
  }
}
