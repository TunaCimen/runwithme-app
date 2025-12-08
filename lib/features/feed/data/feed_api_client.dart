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

  FeedApiClient({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ));

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Get feed posts (paginated)
  Future<PaginatedFeedResponse<FeedPostDto>> getFeed({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed',
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
      '/api/v1/feed/user/$userId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FeedPostDto.fromJson);
  }

  /// Get a single post by ID
  Future<FeedPostDto> getPost(int postId) async {
    final response = await _dio.get('/api/v1/feed/posts/$postId');
    return FeedPostDto.fromJson(_decodeResponse(response.data));
  }

  /// Create a new post
  Future<FeedPostDto> createPost(CreatePostDto request) async {
    final response = await _dio.post(
      '/api/v1/feed/posts',
      data: request.toJson(),
    );
    return FeedPostDto.fromJson(_decodeResponse(response.data));
  }

  /// Update a post
  Future<FeedPostDto> updatePost(int postId, CreatePostDto request) async {
    final response = await _dio.put(
      '/api/v1/feed/posts/$postId',
      data: request.toJson(),
    );
    return FeedPostDto.fromJson(_decodeResponse(response.data));
  }

  /// Delete a post
  Future<void> deletePost(int postId) async {
    await _dio.delete('/api/v1/feed/posts/$postId');
  }

  /// Like a post
  Future<void> likePost(int postId) async {
    await _dio.post('/api/v1/feed/posts/$postId/like');
  }

  /// Unlike a post
  Future<void> unlikePost(int postId) async {
    await _dio.delete('/api/v1/feed/posts/$postId/like');
  }

  /// Get comments for a post (paginated)
  Future<PaginatedFeedResponse<CommentDto>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/feed/posts/$postId/comments',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, CommentDto.fromJson);
  }

  /// Add a comment to a post
  Future<CommentDto> addComment(int postId, AddCommentDto request) async {
    final response = await _dio.post(
      '/api/v1/feed/posts/$postId/comments',
      data: request.toJson(),
    );
    return CommentDto.fromJson(_decodeResponse(response.data));
  }

  /// Delete a comment
  Future<void> deleteComment(int postId, int commentId) async {
    await _dio.delete('/api/v1/feed/posts/$postId/comments/$commentId');
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
    final content = (data['content'] as List<dynamic>?)
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
