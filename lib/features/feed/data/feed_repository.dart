import 'package:dio/dio.dart';
import 'feed_api_client.dart';
import 'models/feed_post_dto.dart';
import 'models/comment_dto.dart';
import 'models/create_post_dto.dart';

/// Result class for feed operations
class FeedResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  FeedResult._({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory FeedResult.success(T data, {String? message}) {
    return FeedResult._(
      success: true,
      data: data,
      message: message,
    );
  }

  factory FeedResult.failure({String? message, String? errorCode}) {
    return FeedResult._(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Repository for feed-related business logic
class FeedRepository {
  final FeedApiClient _apiClient;

  FeedRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    FeedApiClient? apiClient,
  }) : _apiClient = apiClient ?? FeedApiClient(baseUrl: baseUrl);

  /// Set authorization token
  void setAuthToken(String token) {
    _apiClient.setAuthToken(token);
  }

  /// Get feed posts
  Future<FeedResult<PaginatedFeedResponse<FeedPostDto>>> getFeed({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final result = await _apiClient.getFeed(page: page, size: size);
      return FeedResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Get user's posts
  Future<FeedResult<PaginatedFeedResponse<FeedPostDto>>> getUserPosts(
    String userId, {
    int page = 0,
    int size = 10,
  }) async {
    try {
      final result = await _apiClient.getUserPosts(userId, page: page, size: size);
      return FeedResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Get a single post
  Future<FeedResult<FeedPostDto>> getPost(int postId) async {
    try {
      final result = await _apiClient.getPost(postId);
      return FeedResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Create a new post
  Future<FeedResult<FeedPostDto>> createPost(CreatePostDto request) async {
    try {
      final result = await _apiClient.createPost(request);
      return FeedResult.success(result, message: 'Post created successfully');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Update a post
  Future<FeedResult<FeedPostDto>> updatePost(
    int postId,
    CreatePostDto request,
  ) async {
    try {
      final result = await _apiClient.updatePost(postId, request);
      return FeedResult.success(result, message: 'Post updated successfully');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Delete a post
  Future<FeedResult<void>> deletePost(int postId) async {
    try {
      await _apiClient.deletePost(postId);
      return FeedResult.success(null, message: 'Post deleted successfully');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Like a post
  Future<FeedResult<void>> likePost(int postId) async {
    try {
      await _apiClient.likePost(postId);
      return FeedResult.success(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Unlike a post
  Future<FeedResult<void>> unlikePost(int postId) async {
    try {
      await _apiClient.unlikePost(postId);
      return FeedResult.success(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Get comments for a post
  Future<FeedResult<PaginatedFeedResponse<CommentDto>>> getComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await _apiClient.getComments(postId, page: page, size: size);
      return FeedResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Add a comment to a post
  Future<FeedResult<CommentDto>> addComment(
    int postId,
    String commentText,
  ) async {
    try {
      final request = AddCommentDto(commentText: commentText);
      final result = await _apiClient.addComment(postId, request);
      return FeedResult.success(result, message: 'Comment added');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  /// Delete a comment
  Future<FeedResult<void>> deleteComment(int postId, int commentId) async {
    try {
      await _apiClient.deleteComment(postId, commentId);
      return FeedResult.success(null, message: 'Comment deleted');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FeedResult.failure(message: e.toString());
    }
  }

  FeedResult<T> _handleDioError<T>(DioException e) {
    String message;
    String? errorCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please try again.';
        errorCode = 'TIMEOUT';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (statusCode == 401) {
          message = 'Session expired. Please log in again.';
          errorCode = 'UNAUTHORIZED';
        } else if (statusCode == 403) {
          message = 'You do not have permission to perform this action.';
          errorCode = 'FORBIDDEN';
        } else if (statusCode == 404) {
          message = 'Post not found.';
          errorCode = 'NOT_FOUND';
        } else {
          message = responseData?['message'] ?? 'An error occurred.';
          errorCode = 'SERVER_ERROR';
        }
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        errorCode = 'NO_CONNECTION';
        break;
      default:
        message = e.message ?? 'An unexpected error occurred.';
        errorCode = 'UNKNOWN';
    }

    return FeedResult.failure(message: message, errorCode: errorCode);
  }
}
