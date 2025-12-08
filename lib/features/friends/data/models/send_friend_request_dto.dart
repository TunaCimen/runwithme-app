/// DTO for sending a friend request
class SendFriendRequestDto {
  final String receiverId;
  final String? message;

  SendFriendRequestDto({
    required this.receiverId,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'receiverId': receiverId,
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() {
    return 'SendFriendRequestDto(receiverId: $receiverId, message: $message)';
  }
}

/// DTO for responding to a friend request
class RespondToRequestDto {
  final String status; // "ACCEPTED" or "REJECTED"

  RespondToRequestDto({required this.status});

  Map<String, dynamic> toJson() {
    return {
      'status': status,
    };
  }

  static RespondToRequestDto accept() => RespondToRequestDto(status: 'ACCEPTED');
  static RespondToRequestDto reject() => RespondToRequestDto(status: 'REJECTED');
}
