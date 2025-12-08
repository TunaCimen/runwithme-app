import 'package:dio/dio.dart';
import 'friends_api_client.dart';
import 'models/friend_request_dto.dart';
import 'models/friendship_dto.dart';
import 'models/send_friend_request_dto.dart';

/// Result class for friends operations
class FriendsResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  FriendsResult._({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory FriendsResult.success(T data, {String? message}) {
    return FriendsResult._(
      success: true,
      data: data,
      message: message,
    );
  }

  factory FriendsResult.failure({String? message, String? errorCode}) {
    return FriendsResult._(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Repository for friends-related business logic
class FriendsRepository {
  final FriendsApiClient _apiClient;

  FriendsRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    FriendsApiClient? apiClient,
  }) : _apiClient = apiClient ?? FriendsApiClient(baseUrl: baseUrl);

  /// Set authorization token
  void setAuthToken(String token) {
    _apiClient.setAuthToken(token);
  }

  /// Send a friend request
  Future<FriendsResult<FriendRequestDto>> sendFriendRequest({
    required String receiverId,
    String? message,
  }) async {
    try {
      final request = SendFriendRequestDto(
        receiverId: receiverId,
        message: message,
      );
      final result = await _apiClient.sendFriendRequest(request);
      return FriendsResult.success(result, message: 'Friend request sent');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Get sent friend requests
  Future<FriendsResult<PaginatedFriendsResponse<FriendRequestDto>>> getSentRequests({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final result = await _apiClient.getSentRequests(page: page, size: size);
      return FriendsResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Get received friend requests
  Future<FriendsResult<PaginatedFriendsResponse<FriendRequestDto>>> getReceivedRequests({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final result = await _apiClient.getReceivedRequests(page: page, size: size);
      return FriendsResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Accept a friend request
  Future<FriendsResult<FriendRequestDto>> acceptRequest(String requestId) async {
    try {
      final result = await _apiClient.respondToRequest(
        requestId,
        RespondToRequestDto.accept(),
      );
      return FriendsResult.success(result, message: 'Friend request accepted');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Reject a friend request
  Future<FriendsResult<FriendRequestDto>> rejectRequest(String requestId) async {
    try {
      final result = await _apiClient.respondToRequest(
        requestId,
        RespondToRequestDto.reject(),
      );
      return FriendsResult.success(result, message: 'Friend request rejected');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Cancel a sent friend request
  Future<FriendsResult<void>> cancelRequest(String requestId) async {
    try {
      await _apiClient.cancelRequest(requestId);
      return FriendsResult.success(null, message: 'Friend request cancelled');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Get friends list
  Future<FriendsResult<PaginatedFriendsResponse<FriendshipDto>>> getFriends({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final result = await _apiClient.getFriends(page: page, size: size);
      return FriendsResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Remove a friend
  Future<FriendsResult<void>> removeFriend(String friendshipId) async {
    try {
      await _apiClient.removeFriend(friendshipId);
      return FriendsResult.success(null, message: 'Friend removed');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  /// Check friendship status with another user
  Future<FriendsResult<FriendshipStatusDto>> checkFriendshipStatus(
    String otherUserId,
  ) async {
    try {
      final result = await _apiClient.checkFriendshipStatus(otherUserId);
      return FriendsResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return FriendsResult.failure(message: e.toString());
    }
  }

  FriendsResult<T> _handleDioError<T>(DioException e) {
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
          message = 'Resource not found.';
          errorCode = 'NOT_FOUND';
        } else if (statusCode == 409) {
          message = responseData?['message'] ?? 'Request already exists.';
          errorCode = 'CONFLICT';
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

    return FriendsResult.failure(message: message, errorCode: errorCode);
  }
}
