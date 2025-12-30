/// DTO for user recommendation from the API
class RecommendationDto {
  final String userId;
  final String? username;
  final String? profilePic;
  final double combinedScore;
  final double routeSimilarityScore;
  final double preferenceSimilarityScore;
  final int routePairCount;
  final bool hasRoutes;
  final bool hasSurvey;

  RecommendationDto({
    required this.userId,
    this.username,
    this.profilePic,
    required this.combinedScore,
    required this.routeSimilarityScore,
    required this.preferenceSimilarityScore,
    this.routePairCount = 0,
    this.hasRoutes = false,
    this.hasSurvey = false,
  });

  factory RecommendationDto.fromJson(Map<String, dynamic> json) {
    return RecommendationDto(
      userId: json['userId'] ?? '',
      username: json['username'],
      profilePic: json['profilePic'],
      combinedScore: (json['combinedScore'] ?? 0).toDouble(),
      routeSimilarityScore: (json['routeSimilarityScore'] ?? 0).toDouble(),
      preferenceSimilarityScore: (json['preferenceSimilarityScore'] ?? 0)
          .toDouble(),
      routePairCount: json['routePairCount'] ?? 0,
      hasRoutes: json['hasRoutes'] ?? false,
      hasSurvey: json['hasSurvey'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      if (username != null) 'username': username,
      if (profilePic != null) 'profilePic': profilePic,
      'combinedScore': combinedScore,
      'routeSimilarityScore': routeSimilarityScore,
      'preferenceSimilarityScore': preferenceSimilarityScore,
      'routePairCount': routePairCount,
      'hasRoutes': hasRoutes,
      'hasSurvey': hasSurvey,
    };
  }

  /// Get the combined score as an integer percentage (0-100)
  int get matchPercentage => combinedScore.round();

  /// Get a display name (prefer username, fallback to "Runner")
  String get displayName => username ?? 'Runner';

  @override
  String toString() {
    return 'RecommendationDto(userId: $userId, username: $username, combinedScore: $combinedScore)';
  }
}

/// Paginated response for recommendations
class PaginatedRecommendations {
  final List<RecommendationDto> content;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedRecommendations({
    required this.content,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PaginatedRecommendations.fromJson(Map<String, dynamic> json) {
    return PaginatedRecommendations(
      content:
          (json['content'] as List<dynamic>?)
              ?.map(
                (e) => RecommendationDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      pageNumber: json['pageNumber'] ?? json['number'] ?? 0,
      pageSize: json['pageSize'] ?? json['size'] ?? 10,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      first: json['first'] ?? true,
      last: json['last'] ?? true,
    );
  }
}

/// Location filter level for recommendations
enum LocationLevel {
  city,
  country,
  none;

  String toApiString() {
    switch (this) {
      case LocationLevel.city:
        return 'CITY';
      case LocationLevel.country:
        return 'COUNTRY';
      case LocationLevel.none:
        return 'NONE';
    }
  }
}
