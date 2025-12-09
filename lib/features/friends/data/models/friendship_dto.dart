/// DTO for established friendships
///
/// API returns structure:
/// {
///   "user": {
///     "userId": "...",
///     "username": "...",
///     "email": "...",
///     "createdAt": "...",
///     "emailVerified": true
///   },
///   "friendsSince": "..."
/// }
class FriendshipDto {
  // Friend's info (from nested "user" object)
  final String friendUserId;
  final String? friendUsername;
  final String? friendEmail;
  final String? friendProfilePic;
  final String? friendFirstName;
  final String? friendLastName;

  // Friendship metadata
  final DateTime friendsSince;

  // Legacy fields for backwards compatibility
  final String friendshipId;
  final String user1Id;
  final String user2Id;

  FriendshipDto({
    required this.friendUserId,
    this.friendUsername,
    this.friendEmail,
    this.friendProfilePic,
    this.friendFirstName,
    this.friendLastName,
    required this.friendsSince,
    this.friendshipId = '',
    this.user1Id = '',
    this.user2Id = '',
  });

  factory FriendshipDto.fromJson(Map<String, dynamic> json) {
    // Debug: print raw JSON to see field names
    print('[FriendshipDto] Raw JSON: $json');
    print('[FriendshipDto] JSON keys: ${json.keys.toList()}');

    // Handle the new API structure with nested "user" object
    final userObj = json['user'] as Map<String, dynamic>?;

    if (userObj != null) {
      print('[FriendshipDto] Found nested user object: $userObj');
      return FriendshipDto(
        friendUserId: userObj['userId'] ?? userObj['user_id'] ?? userObj['id']?.toString() ?? '',
        friendUsername: userObj['username'],
        friendEmail: userObj['email'],
        friendProfilePic: userObj['profilePic'] ?? userObj['profile_pic'] ?? userObj['profilePicUrl'],
        friendFirstName: userObj['firstName'] ?? userObj['first_name'],
        friendLastName: userObj['lastName'] ?? userObj['last_name'],
        friendsSince: json['friendsSince'] != null
            ? DateTime.parse(json['friendsSince'])
            : (json['friends_since'] != null
                ? DateTime.parse(json['friends_since'])
                : (json['createdAt'] != null
                    ? DateTime.parse(json['createdAt'])
                    : DateTime.now())),
        friendshipId: json['friendshipId'] ?? json['friendship_id'] ?? json['id']?.toString() ?? '',
      );
    }

    // Fallback: Handle old structure with user1Id/user2Id (if backend changes)
    print('[FriendshipDto] No nested user object, using legacy parsing');
    return FriendshipDto(
      friendUserId: json['user2Id'] ?? json['user2_id'] ?? json['userId2'] ?? '',
      friendUsername: json['user2Username'] ?? json['user2_username'],
      friendProfilePic: json['user2ProfilePic'] ?? json['user2_profile_pic'],
      friendFirstName: json['user2FirstName'] ?? json['user2_first_name'],
      friendLastName: json['user2LastName'] ?? json['user2_last_name'],
      friendsSince: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      friendshipId: json['friendshipId'] ?? json['friendship_id'] ?? json['id']?.toString() ?? '',
      user1Id: json['user1Id'] ?? json['user1_id'] ?? '',
      user2Id: json['user2Id'] ?? json['user2_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': {
        'userId': friendUserId,
        'username': friendUsername,
        'email': friendEmail,
        'profilePic': friendProfilePic,
        'firstName': friendFirstName,
        'lastName': friendLastName,
      },
      'friendsSince': friendsSince.toIso8601String(),
      if (friendshipId.isNotEmpty) 'friendshipId': friendshipId,
    };
  }

  FriendshipDto copyWith({
    String? friendUserId,
    String? friendUsername,
    String? friendEmail,
    String? friendProfilePic,
    String? friendFirstName,
    String? friendLastName,
    DateTime? friendsSince,
    String? friendshipId,
  }) {
    return FriendshipDto(
      friendUserId: friendUserId ?? this.friendUserId,
      friendUsername: friendUsername ?? this.friendUsername,
      friendEmail: friendEmail ?? this.friendEmail,
      friendProfilePic: friendProfilePic ?? this.friendProfilePic,
      friendFirstName: friendFirstName ?? this.friendFirstName,
      friendLastName: friendLastName ?? this.friendLastName,
      friendsSince: friendsSince ?? this.friendsSince,
      friendshipId: friendshipId ?? this.friendshipId,
    );
  }

  /// Get the friend's user ID (simplified - just returns the friend's ID)
  String getFriendId(String currentUserId) {
    // The API already returns only the friend's info, so just return it
    return friendUserId;
  }

  /// Get the friend's username
  String? getFriendUsername(String currentUserId) {
    return friendUsername;
  }

  /// Get the friend's profile pic
  String? getFriendProfilePic(String currentUserId) {
    return friendProfilePic;
  }

  /// Get the friend's display name
  String getFriendDisplayName(String currentUserId) {
    // First try first/last name
    if (friendFirstName != null || friendLastName != null) {
      final name = '${friendFirstName ?? ''} ${friendLastName ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    // Fall back to username
    if (friendUsername != null && friendUsername!.isNotEmpty) {
      return friendUsername!;
    }
    return 'Unknown';
  }

  // Legacy getters for backwards compatibility
  DateTime get createdAt => friendsSince;

  @override
  String toString() {
    return 'FriendshipDto(friendUserId: $friendUserId, friendUsername: $friendUsername, friendsSince: $friendsSince)';
  }
}
