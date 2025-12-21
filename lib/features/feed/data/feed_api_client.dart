import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/feed_post_dto.dart';
import 'models/comment_dto.dart';
import 'models/create_post_dto.dart';

/// Paginated response for feed data
class PaginatedFeedResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedFeedResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
}

/// API client for feed endpoints
class FeedApiClient {
  final Dio _dio;

  FeedApiClient({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          );

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Get personalized feed (paginated)
  Future<PaginatedFeedResponse<FeedPostDto>> getFeed({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-posts/feed',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FeedPostDto.fromJson);
  }

  /// Get public feed (paginated)
  Future<PaginatedFeedResponse<FeedPostDto>> getPublicFeed({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-posts/public',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FeedPostDto.fromJson);
  }

  /// Get a user's posts (paginated)
  Future<PaginatedFeedResponse<FeedPostDto>> getUserPosts(
    String userId, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-posts/user/$userId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FeedPostDto.fromJson);
  }

  /// Get a single post by ID
  Future<FeedPostDto> getPost(int postId) async {
    final response = await _dio.get('/api/v1/feed-posts/$postId');
    return FeedPostDto.fromJson(_decodeResponse(response.data));
  }

  /// Create a new post
  Future<FeedPostDto> createPost(CreatePostDto request) async {
    final response = await _dio.post(
      '/api/v1/feed-posts',
      data: request.toJson(),
    );
    return FeedPostDto.fromJson(_decodeResponse(response.data));
  }

  /// Update a post
  Future<FeedPostDto> updatePost(int postId, CreatePostDto request) async {
    final response = await _dio.put(
      '/api/v1/feed-posts/$postId',
      data: request.toJson(),
    );
    return FeedPostDto.fromJson(_decodeResponse(response.data));
  }

  /// Delete a post
  Future<void> deletePost(int postId) async {
    await _dio.delete('/api/v1/feed-posts/$postId');
  }

  // ============ Feed Post Likes ============

  /// Like a post
  Future<void> likePost(int postId) async {
    await _dio.post('/api/v1/feed-post-likes/post/$postId');
  }

  /// Unlike a post
  Future<void> unlikePost(int postId) async {
    await _dio.delete('/api/v1/feed-post-likes/post/$postId');
  }

  /// Check if current user has liked a post
  Future<bool> checkIfLiked(int postId) async {
    final response = await _dio.get(
      '/api/v1/feed-post-likes/post/$postId/check',
    );
    final data = _decodeResponse(response.data);
    // The response could be a boolean directly or wrapped in an object
    if (data is bool) return data;
    if (data is Map) return data['liked'] ?? data['isLiked'] ?? false;
    return false;
  }

  /// Get like count for a post
  Future<int> getLikeCount(int postId) async {
    final response = await _dio.get(
      '/api/v1/feed-post-likes/post/$postId/count',
    );
    final data = _decodeResponse(response.data);
    // The response could be an int directly or wrapped in an object
    if (data is int) return data;
    if (data is Map) return data['count'] ?? data['likeCount'] ?? 0;
    return 0;
  }

  /// Get likes for a post (paginated)
  Future<PaginatedFeedResponse<Map<String, dynamic>>> getPostLikes(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-post-likes/post/$postId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, (json) => json);
  }

  /// Get likes by user (paginated)
  Future<PaginatedFeedResponse<Map<String, dynamic>>> getUserLikes(
    String userId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-post-likes/user/$userId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, (json) => json);
  }

  // ============ Feed Post Comments ============

  /// Get comments for a post (paginated)
  Future<PaginatedFeedResponse<CommentDto>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-post-comments/post/$postId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, CommentDto.fromJson);
  }

  /// Get comment count for a post
  Future<int> getCommentCount(int postId) async {
    final response = await _dio.get(
      '/api/v1/feed-post-comments/post/$postId/count',
    );
    final data = _decodeResponse(response.data);
    // The response could be an int directly or wrapped in an object
    if (data is int) return data;
    if (data is Map) return data['count'] ?? data['commentCount'] ?? 0;
    return 0;
  }

  /// Add a comment to a post
  Future<CommentDto> addComment(int postId, AddCommentDto request) async {
    final response = await _dio.post(
      '/api/v1/feed-post-comments/post/$postId',
      data: request.toJson(),
    );
    return CommentDto.fromJson(_decodeResponse(response.data));
  }

  /// Get a comment by ID
  Future<CommentDto> getComment(int commentId) async {
    final response = await _dio.get('/api/v1/feed-post-comments/$commentId');
    return CommentDto.fromJson(_decodeResponse(response.data));
  }

  /// Update a comment
  Future<CommentDto> updateComment(int commentId, AddCommentDto request) async {
    final response = await _dio.put(
      '/api/v1/feed-post-comments/$commentId',
      data: request.toJson(),
    );
    return CommentDto.fromJson(_decodeResponse(response.data));
  }

  /// Delete a comment
  Future<void> deleteComment(int commentId) async {
    await _dio.delete('/api/v1/feed-post-comments/$commentId');
  }

  /// Get comments by user (paginated)
  Future<PaginatedFeedResponse<CommentDto>> getUserComments(
    String userId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed-post-comments/user/$userId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, CommentDto.fromJson);
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw const FormatException('Unexpected response format');
  }

  PaginatedFeedResponse<T> _parsePaginatedResponse<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final content =
        (data['content'] as List<dynamic>?)
            ?.map((e) => fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PaginatedFeedResponse<T>(
      content: content,
      page: data['page'] ?? data['number'] ?? 0,
      size: data['size'] ?? 10,
      totalElements: data['totalElements'] ?? 0,
      totalPages: data['totalPages'] ?? 0,
      first: data['first'] ?? true,
      last: data['last'] ?? true,
    );
  }
}
