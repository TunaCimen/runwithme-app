/// Friend request status enum
enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  static FriendRequestStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return FriendRequestStatus.pending;
      case 'ACCEPTED':
        return FriendRequestStatus.accepted;
      case 'REJECTED':
        return FriendRequestStatus.rejected;
      case 'CANCELLED':
        return FriendRequestStatus.cancelled;
      default:
        return FriendRequestStatus.pending;
    }
  }

  String toJson() => name.toUpperCase();
}

/// DTO for friend requests
class FriendRequestDto {
  final String requestId;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional denormalized fields for display
  final String? senderUsername;
  final String? senderProfilePic;
  final String? senderFirstName;
  final String? senderLastName;
  final String? receiverUsername;
  final String? receiverProfilePic;
  final String? receiverFirstName;
  final String? receiverLastName;

  FriendRequestDto({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.senderUsername,
    this.senderProfilePic,
    this.senderFirstName,
    this.senderLastName,
    this.receiverUsername,
    this.receiverProfilePic,
    this.receiverFirstName,
    this.receiverLastName,
  });

  factory FriendRequestDto.fromJson(Map<String, dynamic> json) {
    // Debug: print raw JSON to see field names
    print('[FriendRequestDto] Raw JSON: $json');
    print('[FriendRequestDto] JSON keys: ${json.keys.toList()}');

    // Handle nested sender/receiver objects (from list endpoints)
    final senderObj = json['sender'] as Map<String, dynamic>?;
    final receiverObj = json['receiver'] as Map<String, dynamic>?;

    // Extract IDs - try nested objects first, then flat fields
    final senderId = senderObj?['userId'] ?? senderObj?['user_id'] ??
                     json['senderId'] ?? json['sender_id'] ?? '';
    final receiverId = receiverObj?['userId'] ?? receiverObj?['user_id'] ??
                       json['receiverId'] ?? json['receiver_id'] ?? '';

    // Extract usernames - try nested objects first
    final senderUsername = senderObj?['username'] ?? json['senderUsername'] ?? json['sender_username'];
    final receiverUsername = receiverObj?['username'] ?? json['receiverUsername'] ?? json['receiver_username'];

    print('[FriendRequestDto] Parsed: senderId=$senderId, receiverId=$receiverId, senderUsername=$senderUsername, receiverUsername=$receiverUsername');

    return FriendRequestDto(
      requestId: json['requestId'] ?? json['request_id'] ?? json['id']?.toString() ?? '',
      senderId: senderId,
      receiverId: receiverId,
      status: FriendRequestStatus.fromString(json['status'] ?? 'PENDING'),
      message: json['message'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : (json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now()),
      senderUsername: senderUsername,
      senderProfilePic: senderObj?['profilePic'] ?? senderObj?['profile_pic'] ?? json['senderProfilePic'] ?? json['sender_profile_pic'],
      senderFirstName: senderObj?['firstName'] ?? senderObj?['first_name'] ?? json['senderFirstName'] ?? json['sender_first_name'],
      senderLastName: senderObj?['lastName'] ?? senderObj?['last_name'] ?? json['senderLastName'] ?? json['sender_last_name'],
      receiverUsername: receiverUsername,
      receiverProfilePic: receiverObj?['profilePic'] ?? receiverObj?['profile_pic'] ?? json['receiverProfilePic'] ?? json['receiver_profile_pic'],
      receiverFirstName: receiverObj?['firstName'] ?? receiverObj?['first_name'] ?? json['receiverFirstName'] ?? json['receiver_first_name'],
      receiverLastName: receiverObj?['lastName'] ?? receiverObj?['last_name'] ?? json['receiverLastName'] ?? json['receiver_last_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.toJson(),
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (senderUsername != null) 'senderUsername': senderUsername,
      if (senderProfilePic != null) 'senderProfilePic': senderProfilePic,
      if (senderFirstName != null) 'senderFirstName': senderFirstName,
      if (senderLastName != null) 'senderLastName': senderLastName,
      if (receiverUsername != null) 'receiverUsername': receiverUsername,
      if (receiverProfilePic != null) 'receiverProfilePic': receiverProfilePic,
      if (receiverFirstName != null) 'receiverFirstName': receiverFirstName,
      if (receiverLastName != null) 'receiverLastName': receiverLastName,
    };
  }

  FriendRequestDto copyWith({
    String? requestId,
    String? senderId,
    String? receiverId,
    FriendRequestStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? senderUsername,
    String? senderProfilePic,
    String? senderFirstName,
    String? senderLastName,
    String? receiverUsername,
    String? receiverProfilePic,
    String? receiverFirstName,
    String? receiverLastName,
  }) {
    return FriendRequestDto(
      requestId: requestId ?? this.requestId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderUsername: senderUsername ?? this.senderUsername,
      senderProfilePic: senderProfilePic ?? this.senderProfilePic,
      senderFirstName: senderFirstName ?? this.senderFirstName,
      senderLastName: senderLastName ?? this.senderLastName,
      receiverUsername: receiverUsername ?? this.receiverUsername,
      receiverProfilePic: receiverProfilePic ?? this.receiverProfilePic,
      receiverFirstName: receiverFirstName ?? this.receiverFirstName,
      receiverLastName: receiverLastName ?? this.receiverLastName,
    );
  }

  /// Get sender's display name
  String get senderDisplayName {
    if (senderFirstName != null || senderLastName != null) {
      return '${senderFirstName ?? ''} ${senderLastName ?? ''}'.trim();
    }
    return senderUsername ?? 'Unknown';
  }

  /// Get receiver's display name
  String get receiverDisplayName {
    if (receiverFirstName != null || receiverLastName != null) {
      return '${receiverFirstName ?? ''} ${receiverLastName ?? ''}'.trim();
    }
    return receiverUsername ?? 'Unknown';
  }

  @override
  String toString() {
    return 'FriendRequestDto(requestId: $requestId, senderId: $senderId, receiverId: $receiverId, status: $status)';
  }
}
