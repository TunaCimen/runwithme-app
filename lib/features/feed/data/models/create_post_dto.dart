import 'feed_post_dto.dart';

/// DTO for creating a new post
class CreatePostDto {
  final PostType postType;
  final int? routeId;
  final int? runSessionId;
  final String? textContent;
  final String? mediaUrl;
  final PostVisibility visibility;

  CreatePostDto({
    required this.postType,
    this.routeId,
    this.runSessionId,
    this.textContent,
    this.mediaUrl,
    this.visibility = PostVisibility.public,
  });

  Map<String, dynamic> toJson() {
    return {
      'postType': postType.toJson(),
      if (routeId != null) 'routeId': routeId,
      if (runSessionId != null) 'runSessionId': runSessionId,
      if (textContent != null) 'textContent': textContent,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      'visibility': visibility.toJson(),
    };
  }

  /// Create a text post
  factory CreatePostDto.text({
    required String content,
    PostVisibility visibility = PostVisibility.public,
  }) {
    return CreatePostDto(
      postType: PostType.text,
      textContent: content,
      visibility: visibility,
    );
  }

  /// Create a run post
  factory CreatePostDto.run({
    required int runSessionId,
    String? description,
    PostVisibility visibility = PostVisibility.public,
  }) {
    return CreatePostDto(
      postType: PostType.run,
      runSessionId: runSessionId,
      textContent: description,
      visibility: visibility,
    );
  }

  /// Create a route post
  factory CreatePostDto.route({
    required int routeId,
    String? description,
    PostVisibility visibility = PostVisibility.public,
  }) {
    return CreatePostDto(
      postType: PostType.route,
      routeId: routeId,
      textContent: description,
      visibility: visibility,
    );
  }

  /// Create a photo post
  factory CreatePostDto.photo({
    required String mediaUrl,
    String? description,
    PostVisibility visibility = PostVisibility.public,
  }) {
    return CreatePostDto(
      postType: PostType.photo,
      mediaUrl: mediaUrl,
      textContent: description,
      visibility: visibility,
    );
  }

  @override
  String toString() {
    return 'CreatePostDto(postType: $postType, visibility: $visibility)';
  }
}

/// DTO for adding a comment
class AddCommentDto {
  final String commentText;

  AddCommentDto({required this.commentText});

  Map<String, dynamic> toJson() {
    return {
      'commentText': commentText,
    };
  }
}
