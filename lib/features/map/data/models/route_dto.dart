import '../../../../core/models/models.dart';

/// DTO for route API requests and responses
class RouteDto {
  final int? id;
  final String? title;
  final String? description;
  final double? distanceM;
  final int? estimatedDurationS;
  final String? difficulty;
  final bool? isPublic;
  final double? startPointLat;
  final double? startPointLon;
  final double? endPointLat;
  final double? endPointLon;
  final List<RoutePointDto>? points;
  final String? creatorId;
  final String? createdAt;
  final String? updatedAt;

  RouteDto({
    this.id,
    this.title,
    this.description,
    this.distanceM,
    this.estimatedDurationS,
    this.difficulty,
    this.isPublic,
    this.startPointLat,
    this.startPointLon,
    this.endPointLat,
    this.endPointLon,
    this.points,
    this.creatorId,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON
  factory RouteDto.fromJson(Map<String, dynamic> json) {
    var pointsList = <RoutePointDto>[];
    if (json['points'] != null) {
      pointsList = (json['points'] as List)
          .map((point) => RoutePointDto.fromJson(point as Map<String, dynamic>))
          .toList();
    }

    return RouteDto(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String?,
      description: json['description'] as String?,
      distanceM: (json['distanceM'] as num?)?.toDouble(),
      estimatedDurationS: (json['estimatedDurationS'] as num?)?.toInt(),
      difficulty: json['difficulty'] as String?,
      // Check for all possible field names: isPublic, is_public, public
      isPublic: (json['isPublic'] as bool?) ??
          (json['is_public'] as bool?) ??
          (json['public'] as bool?),
      startPointLat: (json['startPointLat'] as num?)?.toDouble(),
      startPointLon: (json['startPointLon'] as num?)?.toDouble(),
      endPointLat: (json['endPointLat'] as num?)?.toDouble(),
      endPointLon: (json['endPointLon'] as num?)?.toDouble(),
      points: pointsList.isNotEmpty ? pointsList : null,
      creatorId: json['creatorId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// Convert to JSON for API requests
  /// Note: createdAt and updatedAt are managed by the backend, so we never send them
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (distanceM != null) 'distanceM': distanceM,
      if (estimatedDurationS != null) 'estimatedDurationS': estimatedDurationS,
      if (difficulty != null) 'difficulty': difficulty,
      if (isPublic != null) 'public': isPublic,
      if (startPointLat != null) 'startPointLat': startPointLat,
      if (startPointLon != null) 'startPointLon': startPointLon,
      if (endPointLat != null) 'endPointLat': endPointLat,
      if (endPointLon != null) 'endPointLon': endPointLon,
      if (points != null) 'points': points!.map((p) => p.toJson()).toList(),
      // Note: creatorId is set by the backend based on the authenticated user
      // createdAt and updatedAt are managed by the backend
    };
  }

  /// Convert DTO to core Route model
  Route toModel() {
    return Route(
      id: id!,
      title: title,
      description: description,
      distanceM: distanceM!,
      estimatedDurationS: estimatedDurationS!,
      difficulty: difficulty,
      isPublic: isPublic ?? true,
      startPointLat: startPointLat!,
      startPointLon: startPointLon!,
      endPointLat: endPointLat!,
      endPointLon: endPointLon!,
      points: points?.map((p) => p.toModel()).toList() ?? [],
      creatorId: creatorId,
      createdAt: DateTime.parse(createdAt!),
      updatedAt: DateTime.parse(updatedAt!),
    );
  }

  /// Create DTO from core Route model
  /// For new routes (id == 0), id and creatorId are set to null so they won't be sent to the API
  factory RouteDto.fromModel(Route route) {
    return RouteDto(
      id: route.id == 0 ? null : route.id,
      title: route.title,
      description: route.description,
      distanceM: route.distanceM,
      estimatedDurationS: route.estimatedDurationS,
      difficulty: route.difficulty,
      isPublic: route.isPublic,
      startPointLat: route.startPointLat,
      startPointLon: route.startPointLon,
      endPointLat: route.endPointLat,
      endPointLon: route.endPointLon,
      points: route.points.map((p) => RoutePointDto.fromModel(p)).toList(),
      creatorId: (route.creatorId == null || route.creatorId!.isEmpty)
          ? null
          : route.creatorId,
      createdAt: route.createdAt.toIso8601String(),
      updatedAt: route.updatedAt.toIso8601String(),
    );
  }
}

/// DTO for route point API requests and responses
class RoutePointDto {
  final int? seqNo;
  final double? latitude;
  final double? longitude;
  final double? elevationM;

  RoutePointDto({this.seqNo, this.latitude, this.longitude, this.elevationM});

  /// Create from JSON
  factory RoutePointDto.fromJson(Map<String, dynamic> json) {
    return RoutePointDto(
      seqNo: (json['seqNo'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      elevationM: (json['elevationM'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (seqNo != null) 'seqNo': seqNo,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (elevationM != null) 'elevationM': elevationM,
    };
  }

  /// Convert DTO to core RoutePoint model
  RoutePoint toModel() {
    return RoutePoint(
      seqNo: seqNo!,
      latitude: latitude!,
      longitude: longitude!,
      elevationM: elevationM,
    );
  }

  /// Create DTO from core RoutePoint model
  /// Note: pointId and routeId are not sent as they are assigned by the backend
  factory RoutePointDto.fromModel(RoutePoint point) {
    return RoutePointDto(
      seqNo: point.seqNo,
      latitude: point.latitude,
      longitude: point.longitude,
      elevationM: point.elevationM,
    );
  }
}

/// Generic paginated response wrapper
class PaginatedRouteResponse {
  final List<RouteDto> content;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedRouteResponse({
    required this.content,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PaginatedRouteResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedRouteResponse(
      content: (json['content'] as List)
          .map((route) => RouteDto.fromJson(route as Map<String, dynamic>))
          .toList(),
      pageNumber: (json['pageNumber'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      first: json['first'] as bool,
      last: json['last'] as bool,
    );
  }
}
