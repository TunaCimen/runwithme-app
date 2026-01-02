import 'package:dio/dio.dart';
import 'mcp_api_client.dart';
import 'models/mcp_message_dto.dart';

/// Result class for MCP operations
class McpResult<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  McpResult._({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory McpResult.success(T data, {String? message}) {
    return McpResult._(success: true, data: data, message: message);
  }

  factory McpResult.failure({String? message, String? errorCode}) {
    return McpResult._(success: false, message: message, errorCode: errorCode);
  }
}

/// Repository for MCP-related business logic
class McpRepository {
  final McpApiClient _apiClient;

  McpRepository({
    String baseUrl = 'http://35.158.35.102:8080',
    McpApiClient? apiClient,
  }) : _apiClient = apiClient ?? McpApiClient(baseUrl: baseUrl);

  /// Set authorization token
  void setAuthToken(String token) {
    _apiClient.setAuthToken(token);
  }

  /// Send a message to the MCP agent
  Future<McpResult<McpMessageDto>> sendMessage(String message) async {
    try {
      final result = await _apiClient.sendMessage(message);
      return McpResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return McpResult.failure(message: e.toString());
    }
  }

  /// Reset MCP conversation history
  Future<McpResult<void>> resetHistory() async {
    try {
      await _apiClient.resetHistory();
      return McpResult.success(null, message: 'Conversation reset');
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return McpResult.failure(message: e.toString());
    }
  }

  /// Get chat history with MCP
  Future<McpResult<List<McpMessageDto>>> getChatHistory({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final result = await _apiClient.getChatHistory(page: page, size: size);
      return McpResult.success(result);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return McpResult.failure(message: e.toString());
    }
  }

  McpResult<T> _handleDioError<T>(DioException e) {
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
          message = 'Service not available.';
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

    return McpResult.failure(message: message, errorCode: errorCode);
  }
}
