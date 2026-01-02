import 'dart:convert';
import 'package:dio/dio.dart';
import 'models/mcp_message_dto.dart';

/// API client for MCP (AI Assistant) endpoints
class McpApiClient {
  final Dio _dio;

  McpApiClient({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
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

  /// Send a message to the MCP agent and get a response
  Future<McpMessageDto> sendMessage(String message) async {
    final response = await _dio.post(
      '/api/v1/mcp/run',
      data: {'message': message},
    );
    final data = _decodeResponse(response.data);

    // The response should contain the AI's reply
    return McpMessageDto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: data['response'] ?? data['message'] ?? data['content'] ?? '',
      isFromUser: false,
      timestamp: DateTime.now(),
    );
  }

  /// Reset the MCP agent conversation history
  Future<void> resetHistory() async {
    await _dio.post('/api/v1/mcp/reset-history');
  }

  /// Get chat history with MCP agent (if available)
  Future<List<McpMessageDto>> getChatHistory({
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/mcp/history',
        queryParameters: {'page': page, 'size': size},
      );
      final data = _decodeResponse(response.data);

      if (data is List) {
        return data
            .map((e) => McpMessageDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (data is Map && data['content'] != null) {
        return (data['content'] as List)
            .map((e) => McpMessageDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      // History endpoint might not exist, return empty list
      return [];
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
}
