import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/message_dto.dart';
import 'models/conversation_dto.dart';
import 'models/send_message_dto.dart';

/// Paginated response for chat data
class PaginatedChatResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PaginatedChatResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });
}

/// API client for chat endpoints
class ChatApiClient {
  final Dio _dio;

  ChatApiClient({
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

  /// Get all conversations
  Future<List<ConversationDto>> getConversations() async {
    final response = await _dio.get('/api/v1/chat/conversations');
    final data = _decodeResponse(response.data);

    if (data is List) {
      return data
          .map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Handle paginated response
    if (data is Map && data['content'] != null) {
      return (data['content'] as List)
          .map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Get chat history with another user (paginated)
  Future<PaginatedChatResponse<MessageDto>> getChatHistory(
    String otherUserId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/v1/chat/history/$otherUserId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = _decodeResponse(response.data);
    return _parsePaginatedResponse(data, MessageDto.fromJson);
  }

  /// Send a message
  Future<MessageDto> sendMessage(SendMessageDto request) async {
    final response = await _dio.post(
      '/api/v1/chat/messages',
      data: request.toJson(),
    );
    return MessageDto.fromJson(_decodeResponse(response.data));
  }

  /// Mark a message as read
  Future<void> markAsRead(int messageId) async {
    await _dio.put('/api/v1/chat/messages/$messageId/read');
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead(String otherUserId) async {
    try {
      await _dio.put('/api/v1/chat/conversations/$otherUserId/read');
    } catch (e) {
      // Endpoint might not exist, ignore errors
    }
  }

  dynamic _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is List) return data;
    if (data is String) {
      final decoded = json.decode(data);
      return decoded;
    }
    throw const FormatException('Unexpected response format');
  }

  PaginatedChatResponse<T> _parsePaginatedResponse<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final content = (data['content'] as List<dynamic>?)
            ?.map((e) => fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PaginatedChatResponse<T>(
      content: content,
      page: data['page'] ?? data['number'] ?? 0,
      size: data['size'] ?? 20,
      totalElements: data['totalElements'] ?? 0,
      totalPages: data['totalPages'] ?? 0,
      first: data['first'] ?? true,
      last: data['last'] ?? true,
    );
  }
}
