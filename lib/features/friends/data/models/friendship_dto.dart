/// DTO for established friendships
class FriendshipDto {
  final String friendshipId;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;

  // Optional denormalized fields for display
  final String? user1Username;
  final String? user1ProfilePic;
  final String? user1FirstName;
  final String? user1LastName;
  final String? user2Username;
  final String? user2ProfilePic;
  final String? user2FirstName;
  final String? user2LastName;

  FriendshipDto({
    required this.friendshipId,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
    this.user1Username,
    this.user1ProfilePic,
    this.user1FirstName,
    this.user1LastName,
    this.user2Username,
    this.user2ProfilePic,
    this.user2FirstName,
    this.user2LastName,
  });

  factory FriendshipDto.fromJson(Map<String, dynamic> json) {
    // Debug: print raw JSON to see field names
    print('[FriendshipDto] Raw JSON: $json');
    print('[FriendshipDto] JSON keys: ${json.keys.toList()}');

    return FriendshipDto(
      friendshipId: json['friendshipId'] ?? json['friendship_id'] ?? json['id']?.toString() ?? '',
      user1Id: json['user1Id'] ?? json['user1_id'] ?? json['userId1'] ?? json['user_id_1'] ?? '',
      user2Id: json['user2Id'] ?? json['user2_id'] ?? json['userId2'] ?? json['user_id_2'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      user1Username: json['user1Username'] ?? json['user1_username'],
      user1ProfilePic: json['user1ProfilePic'] ?? json['user1_profile_pic'],
      user1FirstName: json['user1FirstName'] ?? json['user1_first_name'],
      user1LastName: json['user1LastName'] ?? json['user1_last_name'],
      user2Username: json['user2Username'] ?? json['user2_username'],
      user2ProfilePic: json['user2ProfilePic'] ?? json['user2_profile_pic'],
      user2FirstName: json['user2FirstName'] ?? json['user2_first_name'],
      user2LastName: json['user2LastName'] ?? json['user2_last_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friendshipId': friendshipId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'createdAt': createdAt.toIso8601String(),
      if (user1Username != null) 'user1Username': user1Username,
      if (user1ProfilePic != null) 'user1ProfilePic': user1ProfilePic,
      if (user1FirstName != null) 'user1FirstName': user1FirstName,
      if (user1LastName != null) 'user1LastName': user1LastName,
      if (user2Username != null) 'user2Username': user2Username,
      if (user2ProfilePic != null) 'user2ProfilePic': user2ProfilePic,
      if (user2FirstName != null) 'user2FirstName': user2FirstName,
      if (user2LastName != null) 'user2LastName': user2LastName,
    };
  }

  FriendshipDto copyWith({
    String? friendshipId,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
    String? user1Username,
    String? user1ProfilePic,
    String? user1FirstName,
    String? user1LastName,
    String? user2Username,
    String? user2ProfilePic,
    String? user2FirstName,
    String? user2LastName,
  }) {
    return FriendshipDto(
      friendshipId: friendshipId ?? this.friendshipId,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      createdAt: createdAt ?? this.createdAt,
      user1Username: user1Username ?? this.user1Username,
      user1ProfilePic: user1ProfilePic ?? this.user1ProfilePic,
      user1FirstName: user1FirstName ?? this.user1FirstName,
      user1LastName: user1LastName ?? this.user1LastName,
      user2Username: user2Username ?? this.user2Username,
      user2ProfilePic: user2ProfilePic ?? this.user2ProfilePic,
      user2FirstName: user2FirstName ?? this.user2FirstName,
      user2LastName: user2LastName ?? this.user2LastName,
    );
  }

  /// Get the friend's user ID given the current user's ID
  String getFriendId(String currentUserId) {
    return user1Id == currentUserId ? user2Id : user1Id;
  }

  /// Get the friend's username given the current user's ID
  String? getFriendUsername(String currentUserId) {
    return user1Id == currentUserId ? user2Username : user1Username;
  }

  /// Get the friend's profile pic given the current user's ID
  String? getFriendProfilePic(String currentUserId) {
    return user1Id == currentUserId ? user2ProfilePic : user1ProfilePic;
  }

  /// Get the friend's display name given the current user's ID
  String getFriendDisplayName(String currentUserId) {
    if (user1Id == currentUserId) {
      if (user2FirstName != null || user2LastName != null) {
        return '${user2FirstName ?? ''} ${user2LastName ?? ''}'.trim();
      }
      return user2Username ?? 'Unknown';
    } else {
      if (user1FirstName != null || user1LastName != null) {
        return '${user1FirstName ?? ''} ${user1LastName ?? ''}'.trim();
      }
      return user1Username ?? 'Unknown';
    }
  }

  @override
  String toString() {
    return 'FriendshipDto(friendshipId: $friendshipId, user1Id: $user1Id, user2Id: $user2Id)';
  }
}
