/// User profile model matching the database schema
class UserProfile {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? pronouns;
  final DateTime? birthday;
  final String? expertLevel;
  final String? profilePic;
  final bool profileVisibility;

  // Location references
  final int? regionId;
  final int? subregionId;
  final int? countryId;
  final int? stateId;
  final int? cityId;

  // Visibility check - true if this is a restricted/limited profile
  final bool isRestricted;

  // Username (returned in limited profile)
  final String? username;

  const UserProfile({
    required this.userId,
    this.firstName,
    this.lastName,
    this.pronouns,
    this.birthday,
    this.expertLevel,
    this.profilePic,
    this.profileVisibility = true,
    this.regionId,
    this.subregionId,
    this.countryId,
    this.stateId,
    this.cityId,
    this.isRestricted = false,
    this.username,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Check if this is a limited/restricted profile response
    final isRestricted = _parseBool(
      json['isRestricted'] ?? json['is_restricted'],
      defaultValue: false,
    );

    return UserProfile(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? json['first_name'] as String?,
      lastName: json['lastName'] as String? ?? json['last_name'] as String?,
      pronouns: json['pronouns'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      expertLevel:
          json['expertLevel'] as String? ?? json['expert_level'] as String?,
      profilePic:
          json['profilePic'] as String? ?? json['profile_pic'] as String?,
      profileVisibility: _parseBool(
        json['profileVisibility'] ?? json['profile_visibility'],
        defaultValue: true,
      ),
      regionId:
          (json['regionId'] as num?)?.toInt() ??
          (json['region_id'] as num?)?.toInt(),
      subregionId:
          (json['subregionId'] as num?)?.toInt() ??
          (json['subregion_id'] as num?)?.toInt(),
      countryId:
          (json['countryId'] as num?)?.toInt() ??
          (json['country_id'] as num?)?.toInt(),
      stateId:
          (json['stateId'] as num?)?.toInt() ??
          (json['state_id'] as num?)?.toInt(),
      cityId:
          (json['cityId'] as num?)?.toInt() ??
          (json['city_id'] as num?)?.toInt(),
      isRestricted: isRestricted,
      username: json['username'] as String?,
    );
  }

  /// Parse bool from various formats (bool, String, int)
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return defaultValue;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'pronouns': pronouns,
      'birthday': birthday?.toIso8601String(),
      'expertLevel': expertLevel,
      'profilePic': profilePic,
      'profileVisibility': profileVisibility,
      'regionId': regionId,
      'subregionId': subregionId,
      'countryId': countryId,
      'stateId': stateId,
      'cityId': cityId,
      if (username != null) 'username': username,
    };
  }

  String get fullName {
    if (firstName == null && lastName == null) return username ?? '';
    if (firstName != null && lastName != null) return '$firstName $lastName';
    return firstName ?? lastName ?? username ?? '';
  }

  /// Get display name (prefers full name, falls back to username)
  String get displayName {
    final name = fullName;
    if (name.isNotEmpty) return name;
    return username ?? 'Unknown User';
  }

  @override
  String toString() {
    return 'UserProfile(userId: $userId, name: $fullName, expertLevel: $expertLevel)';
  }

  UserProfile copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? pronouns,
    DateTime? birthday,
    String? expertLevel,
    String? profilePic,
    bool? profileVisibility,
    int? regionId,
    int? subregionId,
    int? countryId,
    int? stateId,
    int? cityId,
    bool? isRestricted,
    String? username,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      pronouns: pronouns ?? this.pronouns,
      birthday: birthday ?? this.birthday,
      expertLevel: expertLevel ?? this.expertLevel,
      profilePic: profilePic ?? this.profilePic,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      regionId: regionId ?? this.regionId,
      subregionId: subregionId ?? this.subregionId,
      countryId: countryId ?? this.countryId,
      stateId: stateId ?? this.stateId,
      cityId: cityId ?? this.cityId,
      isRestricted: isRestricted ?? this.isRestricted,
      username: username ?? this.username,
    );
  }
}
