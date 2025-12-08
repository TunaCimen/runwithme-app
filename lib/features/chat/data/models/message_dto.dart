/// DTO for chat messages
class MessageDto {
  final int id;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  // Denormalized sender info for display
  final String? senderUsername;
  final String? senderProfilePic;
  final String? senderFirstName;
  final String? senderLastName;

  MessageDto({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.senderUsername,
    this.senderProfilePic,
    this.senderFirstName,
    this.senderLastName,
  });

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    return MessageDto(
      id: json['id'] ?? 0,
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      recipientId: json['recipientId'] ?? json['recipient_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      senderUsername: json['senderUsername'] ?? json['sender_username'],
      senderProfilePic: json['senderProfilePic'] ?? json['sender_profile_pic'],
      senderFirstName: json['senderFirstName'] ?? json['sender_first_name'],
      senderLastName: json['senderLastName'] ?? json['sender_last_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  MessageDto copyWith({
    int? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? createdAt,
    bool? isRead,
    String? senderUsername,
    String? senderProfilePic,
    String? senderFirstName,
    String? senderLastName,
  }) {
    return MessageDto(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      senderUsername: senderUsername ?? this.senderUsername,
      senderProfilePic: senderProfilePic ?? this.senderProfilePic,
      senderFirstName: senderFirstName ?? this.senderFirstName,
      senderLastName: senderLastName ?? this.senderLastName,
    );
  }

  /// Get sender's display name
  String get senderDisplayName {
    if (senderFirstName != null || senderLastName != null) {
      return '${senderFirstName ?? ''} ${senderLastName ?? ''}'.trim();
    }
    return senderUsername ?? 'Unknown';
  }

  /// Get time string
  String get timeString {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (messageDate == today) {
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(createdAt).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[createdAt.weekday - 1];
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  @override
  String toString() {
    return 'MessageDto(id: $id, senderId: $senderId, recipientId: $recipientId)';
  }
}
