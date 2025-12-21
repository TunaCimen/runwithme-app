/// RoutePoint model - represents a single point in a route
/// Maps to the `route_points` database table
class RoutePoint {
  final int? pointId;
  final int? routeId;
  final int seqNo;
  final double latitude;
  final double longitude;
  final double? elevationM;

  RoutePoint({
    this.pointId,
    this.routeId,
    required this.seqNo,
    required this.latitude,
    required this.longitude,
    this.elevationM,
  });

  /// Create from JSON - supports both camelCase and snake_case
  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      pointId:
          (json['pointId'] as num?)?.toInt() ??
          (json['point_id'] as num?)?.toInt(),
      routeId:
          (json['routeId'] as num?)?.toInt() ??
          (json['route_id'] as num?)?.toInt(),
      seqNo:
          (json['seqNo'] as num?)?.toInt() ?? (json['seq_no'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevationM:
          (json['elevationM'] as num?)?.toDouble() ??
          (json['elevation_m'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON - uses camelCase
  Map<String, dynamic> toJson() {
    return {
      if (pointId != null) 'pointId': pointId,
      if (routeId != null) 'routeId': routeId,
      'seqNo': seqNo,
      'latitude': latitude,
      'longitude': longitude,
      if (elevationM != null) 'elevationM': elevationM,
    };
  }

  /// Create a copy with updated fields
  RoutePoint copyWith({
    int? pointId,
    int? routeId,
    int? seqNo,
    double? latitude,
    double? longitude,
    double? elevationM,
  }) {
    return RoutePoint(
      pointId: pointId ?? this.pointId,
      routeId: routeId ?? this.routeId,
      seqNo: seqNo ?? this.seqNo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationM: elevationM ?? this.elevationM,
    );
  }

  @override
  String toString() {
    return 'RoutePoint(pointId: $pointId, routeId: $routeId, seqNo: $seqNo, lat: $latitude, lon: $longitude, elevation: $elevationM)';
  }
}
