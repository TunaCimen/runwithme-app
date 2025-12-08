/// Post type enum
enum PostType {
  run,
  route,
  text,
  photo;

  static PostType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RUN':
        return PostType.run;
      case 'ROUTE':
        return PostType.route;
      case 'TEXT':
        return PostType.text;
      case 'PHOTO':
        return PostType.photo;
      default:
        return PostType.text;
    }
  }

  String toJson() => name.toUpperCase();
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
  });

  factory FeedPostDto.fromJson(Map<String, dynamic> json) {
    return FeedPostDto(
      id: json['id'] ?? 0,
      authorId: json['authorId'] ?? json['author_id'] ?? '',
      postType: PostType.fromString(json['postType'] ?? json['post_type'] ?? 'TEXT'),
      routeId: json['routeId'] ?? json['route_id'],
      runSessionId: json['runSessionId'] ?? json['run_session_id'],
      textContent: json['textContent'] ?? json['text_content'],
      mediaUrl: json['mediaUrl'] ?? json['media_url'],
      visibility: PostVisibility.fromString(
          json['visibility'] ?? 'PUBLIC'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      likesCount: json['likesCount'] ?? json['likes_count'] ?? 0,
      commentsCount: json['commentsCount'] ?? json['comments_count'] ?? 0,
      isLikedByCurrentUser:
          json['isLikedByCurrentUser'] ?? json['is_liked_by_current_user'] ?? false,
      authorUsername: json['authorUsername'] ?? json['author_username'],
      authorProfilePic: json['authorProfilePic'] ?? json['author_profile_pic'],
      authorFirstName: json['authorFirstName'] ?? json['author_first_name'],
      authorLastName: json['authorLastName'] ?? json['author_last_name'],
      routeDistanceM: (json['routeDistanceM'] ?? json['route_distance_m'])?.toDouble(),
      routeDurationS: json['routeDurationS'] ?? json['route_duration_s'],
      routeTitle: json['routeTitle'] ?? json['route_title'],
      runDistanceM: (json['runDistanceM'] ?? json['run_distance_m'])?.toDouble(),
      runDurationS: json['runDurationS'] ?? json['run_duration_s'],
      runPaceSecPerKm: (json['runPaceSecPerKm'] ?? json['run_pace_sec_per_km'])?.toDouble(),
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
    );
  }

  /// Get author's display name
  String get authorDisplayName {
    if (authorFirstName != null || authorLastName != null) {
      return '${authorFirstName ?? ''} ${authorLastName ?? ''}'.trim();
    }
    return authorUsername ?? 'Unknown';
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
}
