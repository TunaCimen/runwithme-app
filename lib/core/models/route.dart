import 'route_point.dart';

/// Route model - represents a running route
/// Maps to the `routes` database table
class Route {
  final int id;
  final String? title;
  final String? description;
  final double distanceM;
  final int estimatedDurationS;
  final String? difficulty;
  final bool isPublic;
  final double startPointLat;
  final double startPointLon;
  final double endPointLat;
  final double endPointLon;
  final List<RoutePoint> points;
  final int? creatorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Route({
    required this.id,
    this.title,
    this.description,
    required this.distanceM,
    required this.estimatedDurationS,
    this.difficulty,
    required this.isPublic,
    required this.startPointLat,
    required this.startPointLon,
    required this.endPointLat,
    required this.endPointLon,
    required this.points,
    this.creatorId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON - supports both camelCase and snake_case
  factory Route.fromJson(Map<String, dynamic> json) {
    var pointsList = <RoutePoint>[];
    if (json['points'] != null) {
      pointsList = (json['points'] as List)
          .map((point) => RoutePoint.fromJson(point as Map<String, dynamic>))
          .toList();
    }

    return Route(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      distanceM: (json['distanceM'] as num?)?.toDouble() ??
                 (json['distance_m'] as num).toDouble(),
      estimatedDurationS: (json['estimatedDurationS'] as num?)?.toInt() ??
                          (json['estimated_duration_s'] as num).toInt(),
      difficulty: json['difficulty'] as String?,
      isPublic: (json['isPublic'] as bool?) ??
                (json['is_public'] as bool?) ??
                (json['public'] as bool?) ??
                true,
      startPointLat: (json['startPointLat'] as num?)?.toDouble() ??
                     (json['start_point_lat'] as num).toDouble(),
      startPointLon: (json['startPointLon'] as num?)?.toDouble() ??
                     (json['start_point_lon'] as num).toDouble(),
      endPointLat: (json['endPointLat'] as num?)?.toDouble() ??
                   (json['end_point_lat'] as num).toDouble(),
      endPointLon: (json['endPointLon'] as num?)?.toDouble() ??
                   (json['end_point_lon'] as num).toDouble(),
      points: pointsList,
      creatorId: (json['creatorId'] as num?)?.toInt() ??
                 (json['creator_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String? ??
                                json['created_at'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ??
                                json['updated_at'] as String),
    );
  }

  /// Convert to JSON - uses camelCase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'distanceM': distanceM,
      'estimatedDurationS': estimatedDurationS,
      if (difficulty != null) 'difficulty': difficulty,
      'isPublic': isPublic,
      'startPointLat': startPointLat,
      'startPointLon': startPointLon,
      'endPointLat': endPointLat,
      'endPointLon': endPointLon,
      'points': points.map((point) => point.toJson()).toList(),
      if (creatorId != null) 'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get distance in kilometers
  double get distanceKm => distanceM / 1000.0;

  /// Get formatted distance (e.g., "5.2 km")
  String get formattedDistance {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Get formatted duration (e.g., "30 min" or "1h 15min")
  String get formattedDuration {
    var minutes = estimatedDurationS ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    }
    var hours = minutes ~/ 60;
    var remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }

  /// Create a copy with updated fields
  Route copyWith({
    int? id,
    String? title,
    String? description,
    double? distanceM,
    int? estimatedDurationS,
    String? difficulty,
    bool? isPublic,
    double? startPointLat,
    double? startPointLon,
    double? endPointLat,
    double? endPointLon,
    List<RoutePoint>? points,
    int? creatorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Route(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      distanceM: distanceM ?? this.distanceM,
      estimatedDurationS: estimatedDurationS ?? this.estimatedDurationS,
      difficulty: difficulty ?? this.difficulty,
      isPublic: isPublic ?? this.isPublic,
      startPointLat: startPointLat ?? this.startPointLat,
      startPointLon: startPointLon ?? this.startPointLon,
      endPointLat: endPointLat ?? this.endPointLat,
      endPointLon: endPointLon ?? this.endPointLon,
      points: points ?? this.points,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Route(id: $id, title: $title, distance: ${formattedDistance}, duration: ${formattedDuration}, points: ${points.length})';
  }
}
