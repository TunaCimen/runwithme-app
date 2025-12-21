/// DTO for sending a message
class SendMessageDto {
  final String recipientId;
  final String content;

  SendMessageDto({required this.recipientId, required this.content});

  Map<String, dynamic> toJson() {
    return {'recipientId': recipientId, 'content': content};
  }

  @override
  String toString() {
    return 'SendMessageDto(recipientId: $recipientId, content: ${content.length} chars)';
  }
}
