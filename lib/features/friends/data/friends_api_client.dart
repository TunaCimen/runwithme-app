import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/friend_request_dto.dart';
import 'models/friendship_dto.dart';
import 'models/send_friend_request_dto.dart';

/// Paginated response for friend-related data
class PaginatedFriendsResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedFriendsResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
}

/// API client for friends endpoints
class FriendsApiClient {
  final Dio _dio;

  FriendsApiClient({
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

  /// Send a friend request
  Future<FriendRequestDto> sendFriendRequest(SendFriendRequestDto request) async {
    final response = await _dio.post(
      '/api/v1/friends/requests',
      data: request.toJson(),
    );
    return FriendRequestDto.fromJson(_decodeResponse(response.data));
  }

  /// Get sent friend requests (paginated)
  Future<PaginatedFriendsResponse<FriendRequestDto>> getSentRequests({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/friends/requests/sent',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FriendRequestDto.fromJson);
  }

  /// Get received friend requests (paginated)
  Future<PaginatedFriendsResponse<FriendRequestDto>> getReceivedRequests({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/friends/requests/received',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FriendRequestDto.fromJson);
  }

  /// Respond to a friend request (accept or reject)
  Future<FriendRequestDto> respondToRequest(
    String requestId,
    RespondToRequestDto response,
  ) async {
    final res = await _dio.put(
      '/api/v1/friends/requests/$requestId/respond',
      data: response.toJson(),
    );
    return FriendRequestDto.fromJson(_decodeResponse(res.data));
  }

  /// Cancel a sent friend request
  Future<void> cancelRequest(String requestId) async {
    await _dio.delete('/api/v1/friends/requests/$requestId');
  }

  /// Get current user's friends list (paginated)
  Future<PaginatedFriendsResponse<FriendshipDto>> getFriends({
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/v1/friends',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, FriendshipDto.fromJson);
  }

  /// Remove a friend
  Future<void> removeFriend(String friendshipId) async {
    await _dio.delete('/api/v1/friends/$friendshipId');
  }

  /// Check friendship status with another user
  Future<FriendshipStatusDto> checkFriendshipStatus(String otherUserId) async {
    try {
      final response = await _dio.get('/api/v1/friends/status/$otherUserId');
      return FriendshipStatusDto.fromJson(_decodeResponse(response.data));
    } catch (e) {
      // If endpoint doesn't exist, return none status
      return FriendshipStatusDto(status: FriendshipStatusType.none);
    }
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return json.decode(data) as Map<String, dynamic>;
    throw const FormatException('Unexpected response format');
  }

  PaginatedFriendsResponse<T> _parsePaginatedResponse<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final content = (data['content'] as List<dynamic>?)
            ?.map((e) => fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PaginatedFriendsResponse<T>(
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

/// Friendship status types
enum FriendshipStatusType {
  none,          // No relationship
  friends,       // Already friends
  pendingSent,   // Current user sent request
  pendingReceived, // Current user received request
}

/// DTO for friendship status check
class FriendshipStatusDto {
  final FriendshipStatusType status;
  final String? friendshipId;
  final String? requestId;

  FriendshipStatusDto({
    required this.status,
    this.friendshipId,
    this.requestId,
  });

  factory FriendshipStatusDto.fromJson(Map<String, dynamic> json) {
    var statusStr = json['status'] as String? ?? 'NONE';
    FriendshipStatusType status;

    switch (statusStr.toUpperCase()) {
      case 'FRIENDS':
        status = FriendshipStatusType.friends;
        break;
      case 'PENDING_SENT':
        status = FriendshipStatusType.pendingSent;
        break;
      case 'PENDING_RECEIVED':
        status = FriendshipStatusType.pendingReceived;
        break;
      default:
        status = FriendshipStatusType.none;
    }

    return FriendshipStatusDto(
      status: status,
      friendshipId: json['friendshipId'] ?? json['friendship_id'],
      requestId: json['requestId'] ?? json['request_id'],
    );
  }
}
