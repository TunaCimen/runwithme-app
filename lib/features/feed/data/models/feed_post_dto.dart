/// Post type enum matching backend: TEXT, ROUTE, RUN_SESSION
enum PostType {
  text,
  route,
  run; // Maps to RUN_SESSION on backend

  static PostType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RUN_SESSION':
      case 'RUN': // Support both for backwards compatibility
        return PostType.run;
      case 'ROUTE':
        return PostType.route;
      case 'TEXT':
        return PostType.text;
      default:
        return PostType.text;
    }
  }

  String toJson() {
    switch (this) {
      case PostType.run:
        return 'RUN_SESSION';
      case PostType.route:
        return 'ROUTE';
      case PostType.text:
        return 'TEXT';
    }
  }
}

/// Visibility enum
enum PostVisibility {
  public,
  friends,
  private_;

  static PostVisibility fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PUBLIC':
        return PostVisibility.public;
      case 'FRIENDS':
        return PostVisibility.friends;
      case 'PRIVATE':
        return PostVisibility.private_;
      default:
        return PostVisibility.public;
    }
  }

  String toJson() => name == 'private_' ? 'PRIVATE' : name.toUpperCase();
}

/// Helper function to parse route points with proper type casting
List<Map<String, double>>? _parseRoutePoints(dynamic pointsData) {
  if (pointsData == null) return null;
  if (pointsData is! List) return null;
  if (pointsData.isEmpty) return null;

  final result = <Map<String, double>>[];
  for (final p in pointsData) {
    if (p is Map) {
      final lat = (p['latitude'] ?? p['lat']);
      final lon = (p['longitude'] ?? p['lon'] ?? p['lng']);
      result.add({
        'latitude': (lat is num) ? lat.toDouble() : 0.0,
        'longitude': (lon is num) ? lon.toDouble() : 0.0,
      });
    }
  }
  return result.isEmpty ? null : result;
}

/// DTO for feed posts
class FeedPostDto {
  final int id;
  final String authorId;
  final PostType postType;
  final int? routeId;
  final int? runSessionId;
  final String? textContent;
  final String? mediaUrl;
  final PostVisibility visibility;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByCurrentUser;

  // Denormalized author info for display
  final String? authorUsername;
  final String? authorProfilePic;
  final String? authorFirstName;
  final String? authorLastName;

  // Optional route/run info for display
  final double? routeDistanceM;
  final int? routeDurationS;
  final String? routeTitle;
  final double? runDistanceM;
  final int? runDurationS;
  final double? runPaceSecPerKm;

  // Route/run coordinates for map display
  final double? startPointLat;
  final double? startPointLon;
  final double? endPointLat;
  final double? endPointLon;
  final List<Map<String, double>>? routePoints;

  FeedPostDto({
    required this.id,
    required this.authorId,
    required this.postType,
    this.routeId,
    this.runSessionId,
    this.textContent,
    this.mediaUrl,
    required this.visibility,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByCurrentUser = false,
    this.authorUsername,
    this.authorProfilePic,
    this.authorFirstName,
    this.authorLastName,
    this.routeDistanceM,
    this.routeDurationS,
    this.routeTitle,
    this.runDistanceM,
    this.runDurationS,
    this.runPaceSecPerKm,
    this.startPointLat,
    this.startPointLon,
    this.endPointLat,
    this.endPointLon,
    this.routePoints,
  });

  factory FeedPostDto.fromJson(Map<String, dynamic> json) {
    // Handle nested author object if present
    final author = json['author'] as Map<String, dynamic>?;
    final runner = json['runner'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    final authorData = author ?? runner ?? user;

    // Extract author info from nested object or flat fields
    String? authorUsername = json['authorUsername'] ?? json['author_username'];
    String? authorProfilePic =
        json['authorProfilePic'] ?? json['author_profile_pic'];
    String? authorFirstName =
        json['authorFirstName'] ?? json['author_first_name'];
    String? authorLastName = json['authorLastName'] ?? json['author_last_name'];

    if (authorData != null) {
      authorUsername ??= authorData['username'] ?? authorData['userName'];
      authorProfilePic ??=
          authorData['profilePic'] ??
          authorData['profile_pic'] ??
          authorData['profilePicUrl'];
      authorFirstName ??= authorData['firstName'] ?? authorData['first_name'];
      authorLastName ??= authorData['lastName'] ?? authorData['last_name'];
    }

    return FeedPostDto(
      id: json['id'] ?? 0,
      authorId:
          json['authorId'] ??
          json['author_id'] ??
          json['runnerId'] ??
          json['runner_id'] ??
          '',
      postType: PostType.fromString(
        json['postType'] ?? json['post_type'] ?? 'TEXT',
      ),
      routeId: json['routeId'] ?? json['route_id'],
      runSessionId: json['runSessionId'] ?? json['run_session_id'],
      textContent: json['textContent'] ?? json['text_content'],
      mediaUrl:
          json['mediaUrl'] ??
          json['media_url'] ??
          json['imageUrl'] ??
          json['image_url'] ??
          json['photoUrl'] ??
          json['photo_url'] ??
          json['photo'],
      visibility: PostVisibility.fromString(json['visibility'] ?? 'PUBLIC'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'])
                : DateTime.now()),
      likesCount: json['likesCount'] ?? json['likes_count'] ?? 0,
      commentsCount: json['commentsCount'] ?? json['comments_count'] ?? 0,
      isLikedByCurrentUser:
          json['isLikedByCurrentUser'] ??
          json['is_liked_by_current_user'] ??
          false,
      authorUsername: authorUsername,
      authorProfilePic: authorProfilePic,
      authorFirstName: authorFirstName,
      authorLastName: authorLastName,
      routeDistanceM: (json['routeDistanceM'] ?? json['route_distance_m'])
          ?.toDouble(),
      routeDurationS:
          json['routeDurationS'] ??
          json['route_duration_s'] ??
          json['estimatedDurationS'] ??
          json['estimated_duration_s'],
      routeTitle: json['routeTitle'] ?? json['route_title'],
      runDistanceM: (json['runDistanceM'] ?? json['run_distance_m'])
          ?.toDouble(),
      runDurationS: json['runDurationS'] ?? json['run_duration_s'],
      runPaceSecPerKm: (json['runPaceSecPerKm'] ?? json['run_pace_sec_per_km'])
          ?.toDouble(),
      startPointLat: (json['startPointLat'] ?? json['start_point_lat'])
          ?.toDouble(),
      startPointLon: (json['startPointLon'] ?? json['start_point_lon'])
          ?.toDouble(),
      endPointLat: (json['endPointLat'] ?? json['end_point_lat'])?.toDouble(),
      endPointLon: (json['endPointLon'] ?? json['end_point_lon'])?.toDouble(),
      routePoints: _parseRoutePoints(
        json['routePoints'] ?? json['route_points'] ?? json['points'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'postType': postType.toJson(),
      if (routeId != null) 'routeId': routeId,
      if (runSessionId != null) 'runSessionId': runSessionId,
      if (textContent != null) 'textContent': textContent,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'visibility': visibility.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
    };
  }

  FeedPostDto copyWith({
    int? id,
    String? authorId,
    PostType? postType,
    int? routeId,
    int? runSessionId,
    String? textContent,
    String? mediaUrl,
    PostVisibility? visibility,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByCurrentUser,
    String? authorUsername,
    String? authorProfilePic,
    String? authorFirstName,
    String? authorLastName,
    double? routeDistanceM,
    int? routeDurationS,
    String? routeTitle,
    double? runDistanceM,
    int? runDurationS,
    double? runPaceSecPerKm,
    double? startPointLat,
    double? startPointLon,
    double? endPointLat,
    double? endPointLon,
    List<Map<String, double>>? routePoints,
  }) {
    return FeedPostDto(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      postType: postType ?? this.postType,
      routeId: routeId ?? this.routeId,
      runSessionId: runSessionId ?? this.runSessionId,
      textContent: textContent ?? this.textContent,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      authorUsername: authorUsername ?? this.authorUsername,
      authorProfilePic: authorProfilePic ?? this.authorProfilePic,
      authorFirstName: authorFirstName ?? this.authorFirstName,
      authorLastName: authorLastName ?? this.authorLastName,
      routeDistanceM: routeDistanceM ?? this.routeDistanceM,
      routeDurationS: routeDurationS ?? this.routeDurationS,
      routeTitle: routeTitle ?? this.routeTitle,
      runDistanceM: runDistanceM ?? this.runDistanceM,
      runDurationS: runDurationS ?? this.runDurationS,
      runPaceSecPerKm: runPaceSecPerKm ?? this.runPaceSecPerKm,
      startPointLat: startPointLat ?? this.startPointLat,
      startPointLon: startPointLon ?? this.startPointLon,
      endPointLat: endPointLat ?? this.endPointLat,
      endPointLon: endPointLon ?? this.endPointLon,
      routePoints: routePoints ?? this.routePoints,
    );
  }

  /// Get author's display name
  String get authorDisplayName {
    if (authorFirstName != null || authorLastName != null) {
      return '${authorFirstName ?? ''} ${authorLastName ?? ''}'.trim();
    }
    return authorUsername ?? 'Unknown';
  }

  /// Get the run/route title or generate a time-based fallback
  String get displayTitle {
    // If we have a route title, use it
    if (routeTitle != null && routeTitle!.isNotEmpty) {
      return routeTitle!;
    }
    // Generate time-based name as fallback
    return _getTimeBasedRunName();
  }

  /// Generate a time-based run name as fallback
  String _getTimeBasedRunName() {
    final hour = createdAt.hour;
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

  /// Get formatted distance (in km)
  String get formattedDistance {
    final distance = runDistanceM ?? routeDistanceM;
    if (distance == null) return '';
    return (distance / 1000).toStringAsFixed(2);
  }

  /// Get formatted duration
  String get formattedDuration {
    final seconds = runDurationS ?? routeDurationS;
    if (seconds == null) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Get formatted pace (min/km)
  String get formattedPace {
    if (runPaceSecPerKm == null) return '';
    final minutes = runPaceSecPerKm! ~/ 60;
    final seconds = (runPaceSecPerKm! % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'FeedPostDto(id: $id, authorId: $authorId, postType: $postType)';
  }

  /// Get the full image URL for mediaUrl
  /// Constructs proper URL from filename if needed
  String? getFullMediaUrl({
    String baseUrl = 'http://35.158.35.102:8080',
    String folder = 'posts',
  }) {
    if (mediaUrl == null || mediaUrl!.isEmpty) return null;

    // If it's already a full URL, return as is
    if (mediaUrl!.startsWith('http://') || mediaUrl!.startsWith('https://')) {
      return mediaUrl;
    }

    // If it already starts with /api/v1/images, just prepend baseUrl
    if (mediaUrl!.startsWith('/api/v1/images')) {
      return '$baseUrl$mediaUrl';
    }

    // If it starts with api/v1/images (without leading slash)
    if (mediaUrl!.startsWith('api/v1/images')) {
      return '$baseUrl/$mediaUrl';
    }

    // Otherwise, it's just a filename - construct the full URL
    return '$baseUrl/api/v1/images/$folder/$mediaUrl';
  }
}
