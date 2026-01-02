/// DTO for MCP agent messages
class McpMessageDto {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;

  McpMessageDto({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
  });

  factory McpMessageDto.fromJson(Map<String, dynamic> json) {
    return McpMessageDto(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? json['message'] ?? '',
      isFromUser: json['isFromUser'] ?? json['is_from_user'] ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isFromUser': isFromUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  McpMessageDto copyWith({
    String? id,
    String? content,
    bool? isFromUser,
    DateTime? timestamp,
  }) {
    return McpMessageDto(
      id: id ?? this.id,
      content: content ?? this.content,
      isFromUser: isFromUser ?? this.isFromUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'McpMessageDto(id: $id, isFromUser: $isFromUser, content: ${content.length > 50 ? '${content.substring(0, 47)}...' : content})';
  }
}
