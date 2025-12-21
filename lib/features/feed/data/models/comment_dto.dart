/// DTO for post comments
class CommentDto {
  final int id;
  final int postId;
  final String userId;
  final String commentText;
  final DateTime createdAt;

  // Denormalized author info for display
  final String? authorUsername;
  final String? authorProfilePic;
  final String? authorFirstName;
  final String? authorLastName;

  CommentDto({
    required this.id,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    this.authorUsername,
    this.authorProfilePic,
    this.authorFirstName,
    this.authorLastName,
  });

  factory CommentDto.fromJson(Map<String, dynamic> json) {
    // Handle nested author object if present
    final author = json['author'] as Map<String, dynamic>?;
    final user = json['user'] as Map<String, dynamic>?;
    final authorData = author ?? user;

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

    return CommentDto(
      id: json['id'] ?? 0,
      postId: json['postId'] ?? json['post_id'] ?? 0,
      userId: json['userId'] ?? json['user_id'] ?? '',
      commentText: json['commentText'] ?? json['comment_text'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'])
                : DateTime.now()),
      authorUsername: authorUsername,
      authorProfilePic: authorProfilePic,
      authorFirstName: authorFirstName,
      authorLastName: authorLastName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'commentText': commentText,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  CommentDto copyWith({
    int? id,
    int? postId,
    String? userId,
    String? commentText,
    DateTime? createdAt,
    String? authorUsername,
    String? authorProfilePic,
    String? authorFirstName,
    String? authorLastName,
  }) {
    return CommentDto(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      commentText: commentText ?? this.commentText,
      createdAt: createdAt ?? this.createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorProfilePic: authorProfilePic ?? this.authorProfilePic,
      authorFirstName: authorFirstName ?? this.authorFirstName,
      authorLastName: authorLastName ?? this.authorLastName,
    );
  }

  /// Get author's display name
  String get authorDisplayName {
    if (authorFirstName != null || authorLastName != null) {
      return '${authorFirstName ?? ''} ${authorLastName ?? ''}'.trim();
    }
    return authorUsername ?? 'Unknown';
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
    return 'CommentDto(id: $id, postId: $postId, userId: $userId)';
  }
}
