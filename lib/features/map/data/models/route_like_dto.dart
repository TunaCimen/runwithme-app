import '../../../../core/models/models.dart';

/// DTO for route like API requests and responses
class RouteLikeDto {
  final int? routeId;
  final String? userId;
  final String? createdAt;

  RouteLikeDto({this.routeId, this.userId, this.createdAt});

  /// Create from JSON
  factory RouteLikeDto.fromJson(Map<String, dynamic> json) {
    return RouteLikeDto(
      routeId: (json['routeId'] as num?)?.toInt(),
      userId: json['userId'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (routeId != null) 'routeId': routeId,
      if (userId != null) 'userId': userId,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  /// Convert DTO to core RouteLike model
  RouteLike toModel() {
    return RouteLike(
      routeId: routeId!,
      userId: userId!,
      createdAt: DateTime.parse(createdAt!),
    );
  }

  /// Create DTO from core RouteLike model
  factory RouteLikeDto.fromModel(RouteLike like) {
    return RouteLikeDto(
      routeId: like.routeId,
      userId: like.userId,
      createdAt: like.createdAt.toIso8601String(),
    );
  }
}

/// Paginated route likes response
class PaginatedRouteLikeResponse {
  final List<RouteLikeDto> content;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedRouteLikeResponse({
    required this.content,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PaginatedRouteLikeResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedRouteLikeResponse(
      content: (json['content'] as List)
          .map((like) => RouteLikeDto.fromJson(like as Map<String, dynamic>))
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
