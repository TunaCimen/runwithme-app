import '../models/user.dart';
import '../models/user_profile.dart';
import '../models/location/location.dart';

/// View model combining User and UserProfile for UI presentation
class UserViewModel {
  final User user;
  final UserProfile? profile;
  final Location? location;

  const UserViewModel({
    required this.user,
    this.profile,
    this.location,
  });

  String get userId => user.userId;
  String get username => user.username;
  String get email => user.email;

  // Profile-related getters with fallbacks
  String get displayName {
    if (profile?.fullName.isNotEmpty ?? false) {
      return profile!.fullName;
    }
    return username;
  }

  String? get firstName => profile?.firstName;
  String? get lastName => profile?.lastName;
  String? get pronouns => profile?.pronouns;
  DateTime? get birthday => profile?.birthday;
  String? get expertLevel => profile?.expertLevel;
  String? get profilePic => profile?.profilePic;
  bool get isProfileVisible => profile?.profileVisibility ?? true;

  // Location-related getters
  String? get locationDisplayName => location?.displayName;
  String? get locationShortName => location?.shortDisplayName;

  /// Calculate age from birthday
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    var age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }

  /// Check if profile is complete (has basic info filled)
  bool get isProfileComplete {
    return profile != null &&
        profile!.firstName != null &&
        profile!.lastName != null;
  }

  @override
  String toString() {
    return 'UserViewModel(id: $userId, name: $displayName, email: $email)';
  }

  UserViewModel copyWith({
    User? user,
    UserProfile? profile,
    Location? location,
  }) {
    return UserViewModel(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      location: location ?? this.location,
    );
  }
}
