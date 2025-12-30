import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'models/message_dto.dart';

/// Event types from WebSocket
enum ChatEventType {
  newMessage,
  readReceipt,
}

/// Read receipt payload from WebSocket
class ReadReceiptPayload {
  final String readByUserId;
  final String readByUsername;
  final List<int> messageIds;

  ReadReceiptPayload({
    required this.readByUserId,
    required this.readByUsername,
    required this.messageIds,
  });

  factory ReadReceiptPayload.fromJson(Map<String, dynamic> json) {
    return ReadReceiptPayload(
      readByUserId: json['readByUserId'] ?? '',
      readByUsername: json['readByUsername'] ?? '',
      messageIds: (json['messageIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

/// Chat event wrapper from WebSocket
class ChatEvent {
  final ChatEventType type;
  final dynamic payload;
  final DateTime timestamp;

  ChatEvent({
    required this.type,
    required this.payload,
    required this.timestamp,
  });

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? '';
    final type = typeStr == 'NEW_MESSAGE'
        ? ChatEventType.newMessage
        : ChatEventType.readReceipt;

    dynamic payload;
    if (type == ChatEventType.newMessage) {
      payload = MessageDto.fromJson(json['payload'] as Map<String, dynamic>);
    } else {
      payload =
          ReadReceiptPayload.fromJson(json['payload'] as Map<String, dynamic>);
    }

    return ChatEvent(
      type: type,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// WebSocket service for real-time chat
class ChatWebSocketService {
  static final ChatWebSocketService _instance =
      ChatWebSocketService._internal();
  factory ChatWebSocketService() => _instance;
  ChatWebSocketService._internal();

  StompClient? _stompClient;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Callbacks
  Function(MessageDto)? onNewMessage;
  Function(ReadReceiptPayload)? onReadReceipt;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String)? onError;

  // Stream controllers for broadcasting events
  final _newMessageController = StreamController<MessageDto>.broadcast();
  final _readReceiptController = StreamController<ReadReceiptPayload>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<MessageDto> get newMessageStream => _newMessageController.stream;
  Stream<ReadReceiptPayload> get readReceiptStream =>
      _readReceiptController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _isConnected;

  /// Connect to WebSocket with JWT token
  void connect(String token, {String baseUrl = 'http://35.158.35.102:8080'}) {
    if (_isConnected || _isConnecting) {
      debugPrint('[ChatWebSocket] Already connected or connecting');
      return;
    }

    _isConnecting = true;

    // Convert http to ws URL for STOMP over WebSocket
    // Use /ws/websocket endpoint which is the standard Spring WebSocket STOMP endpoint
    var wsUrl = baseUrl.replaceFirst('http://', 'ws://');
    wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    wsUrl = '$wsUrl/ws/websocket';

    debugPrint('[ChatWebSocket] Connecting to $wsUrl');

    try {
      _stompClient = StompClient(
        config: StompConfig.sockJS(
          url: '$baseUrl/ws',
          onConnect: _onConnect,
          onDisconnect: _onDisconnect,
          onStompError: _onStompError,
          onWebSocketError: _onWebSocketError,
          stompConnectHeaders: {
            'Authorization': 'Bearer $token',
          },
          webSocketConnectHeaders: {
            'Authorization': 'Bearer $token',
          },
          reconnectDelay: const Duration(seconds: 10),
          heartbeatIncoming: const Duration(seconds: 10),
          heartbeatOutgoing: const Duration(seconds: 10),
        ),
      );

      _stompClient!.activate();
    } catch (e) {
      debugPrint('[ChatWebSocket] Error creating STOMP client: $e');
      _isConnecting = false;
    }
  }

  void _onConnect(StompFrame frame) {
    debugPrint('[ChatWebSocket] Connected');
    _isConnected = true;
    _isConnecting = false;
    _connectionStateController.add(true);
    onConnected?.call();

    // Subscribe to personal message queue
    _stompClient!.subscribe(
      destination: '/user/queue/messages',
      callback: _handleMessage,
    );
  }

  void _onDisconnect(StompFrame frame) {
    debugPrint('[ChatWebSocket] Disconnected');
    _isConnected = false;
    _isConnecting = false;
    _connectionStateController.add(false);
    onDisconnected?.call();
  }

  void _onStompError(StompFrame frame) {
    debugPrint('[ChatWebSocket] STOMP error: ${frame.body}');
    _isConnected = false;
    _isConnecting = false;
    onError?.call(frame.body ?? 'STOMP error');
  }

  void _onWebSocketError(dynamic error) {
    debugPrint('[ChatWebSocket] WebSocket error: $error');
    _isConnected = false;
    _isConnecting = false;
    onError?.call(error.toString());
  }

  void _handleMessage(StompFrame frame) {
    if (frame.body == null) return;

    try {
      final json = jsonDecode(frame.body!) as Map<String, dynamic>;
      final event = ChatEvent.fromJson(json);

      debugPrint(
        '[ChatWebSocket] Received event: ${event.type}, payload type: ${event.payload.runtimeType}',
      );

      switch (event.type) {
        case ChatEventType.newMessage:
          final message = event.payload as MessageDto;
          _newMessageController.add(message);
          onNewMessage?.call(message);
          break;

        case ChatEventType.readReceipt:
          final receipt = event.payload as ReadReceiptPayload;
          _readReceiptController.add(receipt);
          onReadReceipt?.call(receipt);
          break;
      }
    } catch (e) {
      debugPrint('[ChatWebSocket] Error parsing message: $e');
    }
  }

  /// Send a message via WebSocket
  void sendMessage({required String recipientId, required String content}) {
    if (!_isConnected || _stompClient == null) {
      debugPrint('[ChatWebSocket] Cannot send message: not connected');
      return;
    }

    final payload = jsonEncode({
      'recipientId': recipientId,
      'content': content,
    });

    _stompClient!.send(
      destination: '/app/chat',
      body: payload,
    );

    debugPrint('[ChatWebSocket] Message sent to $recipientId');
  }

  /// Disconnect from WebSocket
  void disconnect() {
    debugPrint('[ChatWebSocket] Disconnecting');
    _stompClient?.deactivate();
    _isConnected = false;
    _isConnecting = false;
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _newMessageController.close();
    _readReceiptController.close();
    _connectionStateController.close();
  }
}
