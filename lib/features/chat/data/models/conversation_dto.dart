import 'message_dto.dart';

/// DTO for a conversation (chat thread)
class ConversationDto {
  final String oderId; // The other participant's user ID
  final String otherUsername;
  final String? otherProfilePic;
  final String? otherFirstName;
  final String? otherLastName;
  final MessageDto? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;

  ConversationDto({
    required this.oderId,
    required this.otherUsername,
    this.otherProfilePic,
    this.otherFirstName,
    this.otherLastName,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      oderId: json['otherId'] ?? json['other_id'] ?? '',
      otherUsername:
          json['otherUsername'] ?? json['other_username'] ?? 'Unknown',
      otherProfilePic: json['otherProfilePic'] ?? json['other_profile_pic'],
      otherFirstName: json['otherFirstName'] ?? json['other_first_name'],
      otherLastName: json['otherLastName'] ?? json['other_last_name'],
      lastMessage: json['lastMessage'] != null
          ? MessageDto.fromJson(json['lastMessage'])
          : (json['last_message'] != null
                ? MessageDto.fromJson(json['last_message'])
                : null),
      unreadCount: json['unreadCount'] ?? json['unread_count'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : (json['last_message_at'] != null
                ? DateTime.parse(json['last_message_at'])
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'otherId': oderId,
      'otherUsername': otherUsername,
      if (otherProfilePic != null) 'otherProfilePic': otherProfilePic,
      if (otherFirstName != null) 'otherFirstName': otherFirstName,
      if (otherLastName != null) 'otherLastName': otherLastName,
      if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
      'unreadCount': unreadCount,
      if (lastMessageAt != null)
        'lastMessageAt': lastMessageAt!.toIso8601String(),
    };
  }

  ConversationDto copyWith({
    String? oderId,
    String? otherUsername,
    String? otherProfilePic,
    String? otherFirstName,
    String? otherLastName,
    MessageDto? lastMessage,
    int? unreadCount,
    DateTime? lastMessageAt,
  }) {
    return ConversationDto(
      oderId: oderId ?? this.oderId,
      otherUsername: otherUsername ?? this.otherUsername,
      otherProfilePic: otherProfilePic ?? this.otherProfilePic,
      otherFirstName: otherFirstName ?? this.otherFirstName,
      otherLastName: otherLastName ?? this.otherLastName,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  /// Get the other user's display name
  String get otherDisplayName {
    if (otherFirstName != null || otherLastName != null) {
      return '${otherFirstName ?? ''} ${otherLastName ?? ''}'.trim();
    }
    return otherUsername;
  }

  /// Get last message preview (truncated)
  String get lastMessagePreview {
    if (lastMessage == null) return 'No messages yet';
    final content = lastMessage!.content;
    if (content.length > 50) {
      return '${content.substring(0, 47)}...';
    }
    return content;
  }

  /// Get formatted time for last message
  String get lastMessageTime {
    if (lastMessageAt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      lastMessageAt!.year,
      lastMessageAt!.month,
      lastMessageAt!.day,
    );

    if (messageDate == today) {
      return '${lastMessageAt!.hour.toString().padLeft(2, '0')}:${lastMessageAt!.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(lastMessageAt!).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[lastMessageAt!.weekday - 1];
    } else {
      return '${lastMessageAt!.day}/${lastMessageAt!.month}';
    }
  }

  @override
  String toString() {
    return 'ConversationDto(otherId: $oderId, otherUsername: $otherUsername, unreadCount: $unreadCount)';
  }
}
