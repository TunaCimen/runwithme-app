import 'package:dio/dio.dart';
import 'chat_api_client.dart';
import 'models/message_dto.dart';
import 'models/send_message_dto.dart';

/// Result class for chat operations
class ChatResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  ChatResult._({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory ChatResult.success(T data, {String? message}) {
    return ChatResult._(
      success: true,
      data: data,
      message: message,
    );
  }

  factory ChatResult.failure({String? message, String? errorCode}) {
    return ChatResult._(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Repository for chat-related business logic
class ChatRepository {
  final ChatApiClient _apiClient;

  ChatRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    ChatApiClient? apiClient,
  }) : _apiClient = apiClient ?? ChatApiClient(baseUrl: baseUrl);

  /// Set authorization token
  void setAuthToken(String token) {
    _apiClient.setAuthToken(token);
  }

  /// Get all messages for authenticated user
  Future<ChatResult<List<MessageDto>>> getAllMessages() async {
    try {
      final result = await _apiClient.getAllMessages();
      return ChatResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ChatResult.failure(message: e.toString());
    }
  }

  /// Get connected WebSocket users
  Future<ChatResult<List<String>>> getConnectedUsers() async {
    try {
      final result = await _apiClient.getConnectedUsers();
      return ChatResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ChatResult.failure(message: e.toString());
    }
  }

  /// Get chat history with another user
  Future<ChatResult<PaginatedChatResponse<MessageDto>>> getChatHistory(
    String otherUserId, {
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await _apiClient.getChatHistory(
        otherUserId,
        page: page,
        size: size,
      );
      return ChatResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ChatResult.failure(message: e.toString());
    }
  }

  /// Send a message
  Future<ChatResult<MessageDto>> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    try {
      final request = SendMessageDto(
        recipientId: recipientId,
        content: content,
      );
      final result = await _apiClient.sendMessage(request);
      return ChatResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ChatResult.failure(message: e.toString());
    }
  }

  /// Mark messages as read
  Future<ChatResult<void>> markAsRead({String? otherUserId, List<int>? messageIds}) async {
    try {
      await _apiClient.markAsRead(otherUserId: otherUserId, messageIds: messageIds);
      return ChatResult.success(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ChatResult.failure(message: e.toString());
    }
  }

  /// Mark all messages in a conversation as read
  Future<ChatResult<void>> markConversationAsRead(String otherUserId) async {
    try {
      await _apiClient.markConversationAsRead(otherUserId);
      return ChatResult.success(null);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ChatResult.failure(message: e.toString());
    }
  }

  ChatResult<T> _handleDioError<T>(DioException e) {
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
          message = 'Conversation not found.';
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

    return ChatResult.failure(message: message, errorCode: errorCode);
  }
}
