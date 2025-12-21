/// RouteLike model - represents a user's like on a route
/// Maps to the `route_likes` database table
class RouteLike {
  final int routeId;
  final String userId;
  final DateTime createdAt;

  RouteLike({
    required this.routeId,
    required this.userId,
    required this.createdAt,
  });

  /// Create from JSON - supports both camelCase and snake_case
  factory RouteLike.fromJson(Map<String, dynamic> json) {
    return RouteLike(
      routeId:
          (json['routeId'] as num?)?.toInt() ??
          (json['route_id'] as num).toInt(),
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? json['created_at'] as String,
      ),
    );
  }

  /// Convert to JSON - uses camelCase
  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  RouteLike copyWith({int? routeId, String? userId, DateTime? createdAt}) {
    return RouteLike(
      routeId: routeId ?? this.routeId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'RouteLike(routeId: $routeId, userId: $userId, createdAt: $createdAt)';
  }
}
