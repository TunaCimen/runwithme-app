/// Survey response model for running preferences questionnaire
class SurveyResponseDto {
  final int? id;
  final String? userId; // Required for creating/updating
  final String? preferredDays; // Comma-separated: "MON,TUE,WED"
  final String? timeOfDay; // Comma-separated: "EARLY_BIRD,MORNING"
  final String?
  experienceLevel; // BEGINNER, AMATEUR, INTERMEDIATE, PROFESSIONAL
  final String? activityType; // WALKING, HIKING, LEISURELY, COMPETITIVE
  final String? intensityPreference; // HIGH_INTENSITY, STEADY_STATE
  final String? socialVibe; // SILENT, SOCIAL
  final String?
  motivationType; // MENTAL_HEALTH, WEIGHT_LOSS, TRAINING, SOCIALIZING
  final String? coachingStyle; // PUSHER, COMPANION
  final String? musicPreference; // HEADPHONES, NATURE
  final bool? matchGenderPreference;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SurveyResponseDto({
    this.id,
    this.userId,
    this.preferredDays,
    this.timeOfDay,
    this.experienceLevel,
    this.activityType,
    this.intensityPreference,
    this.socialVibe,
    this.motivationType,
    this.coachingStyle,
    this.musicPreference,
    this.matchGenderPreference,
    this.createdAt,
    this.updatedAt,
  });

  factory SurveyResponseDto.fromJson(Map<String, dynamic> json) {
    return SurveyResponseDto(
      id: json['id'] as int?,
      userId: json['userId'] as String?,
      preferredDays: json['preferredDays'] as String?,
      timeOfDay: json['timeOfDay'] as String?,
      experienceLevel: json['experienceLevel'] as String?,
      activityType: json['activityType'] as String?,
      intensityPreference: json['intensityPreference'] as String?,
      socialVibe: json['socialVibe'] as String?,
      motivationType: json['motivationType'] as String?,
      coachingStyle: json['coachingStyle'] as String?,
      musicPreference: json['musicPreference'] as String?,
      matchGenderPreference: json['matchGenderPreference'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'userId': userId,
      'preferredDays': preferredDays,
      'timeOfDay': timeOfDay,
      'experienceLevel': experienceLevel,
      'activityType': activityType,
      'intensityPreference': intensityPreference,
      'socialVibe': socialVibe,
      'motivationType': motivationType,
      'coachingStyle': coachingStyle,
      'musicPreference': musicPreference,
      'matchGenderPreference': matchGenderPreference,
    };
  }

  SurveyResponseDto copyWith({
    int? id,
    String? userId,
    String? preferredDays,
    String? timeOfDay,
    String? experienceLevel,
    String? activityType,
    String? intensityPreference,
    String? socialVibe,
    String? motivationType,
    String? coachingStyle,
    String? musicPreference,
    bool? matchGenderPreference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SurveyResponseDto(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      preferredDays: preferredDays ?? this.preferredDays,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      activityType: activityType ?? this.activityType,
      intensityPreference: intensityPreference ?? this.intensityPreference,
      socialVibe: socialVibe ?? this.socialVibe,
      motivationType: motivationType ?? this.motivationType,
      coachingStyle: coachingStyle ?? this.coachingStyle,
      musicPreference: musicPreference ?? this.musicPreference,
      matchGenderPreference:
          matchGenderPreference ?? this.matchGenderPreference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods for multi-select fields
  List<String> get preferredDaysList =>
      preferredDays?.split(',').where((s) => s.isNotEmpty).toList() ?? [];

  List<String> get timeOfDayList =>
      timeOfDay?.split(',').where((s) => s.isNotEmpty).toList() ?? [];

  bool get isComplete =>
      preferredDays != null &&
      preferredDays!.isNotEmpty &&
      timeOfDay != null &&
      timeOfDay!.isNotEmpty &&
      experienceLevel != null &&
      activityType != null &&
      intensityPreference != null &&
      socialVibe != null &&
      motivationType != null &&
      coachingStyle != null &&
      musicPreference != null &&
      matchGenderPreference != null;

  @override
  String toString() {
    return 'SurveyResponseDto(id: $id, experienceLevel: $experienceLevel, activityType: $activityType)';
  }
}

/// Enum-like class for preferred days
class PreferredDay {
  static const String monday = 'MON';
  static const String tuesday = 'TUE';
  static const String wednesday = 'WED';
  static const String thursday = 'THU';
  static const String friday = 'FRI';
  static const String saturday = 'SAT';
  static const String sunday = 'SUN';

  static const List<String> all = [
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
  ];

  static String displayName(String day) {
    switch (day) {
      case monday:
        return 'Mon';
      case tuesday:
        return 'Tue';
      case wednesday:
        return 'Wed';
      case thursday:
        return 'Thu';
      case friday:
        return 'Fri';
      case saturday:
        return 'Sat';
      case sunday:
        return 'Sun';
      default:
        return day;
    }
  }
}

/// Enum-like class for time of day preferences
class TimeOfDayPreference {
  static const String earlyBird = 'EARLY_BIRD';
  static const String morning = 'MORNING';
  static const String lunch = 'LUNCH';
  static const String afternoon = 'AFTERNOON';
  static const String evening = 'EVENING';
  static const String night = 'NIGHT';

  static const List<String> all = [
    earlyBird,
    morning,
    lunch,
    afternoon,
    evening,
    night,
  ];

  static String displayName(String time) {
    switch (time) {
      case earlyBird:
        return '5-8 AM';
      case morning:
        return '8-11 AM';
      case lunch:
        return '12-2 PM';
      case afternoon:
        return '2-5 PM';
      case evening:
        return '5-9 PM';
      case night:
        return '9 PM+';
      default:
        return time;
    }
  }

  static String label(String time) {
    switch (time) {
      case earlyBird:
        return 'Early Bird';
      case morning:
        return 'Morning';
      case lunch:
        return 'Lunch';
      case afternoon:
        return 'Afternoon';
      case evening:
        return 'Evening';
      case night:
        return 'Night';
      default:
        return time;
    }
  }
}

/// Enum-like class for experience levels
class ExperienceLevel {
  static const String beginner = 'BEGINNER';
  static const String amateur = 'AMATEUR';
  static const String intermediate = 'INTERMEDIATE';
  static const String professional = 'PROFESSIONAL';

  static const List<String> all = [
    beginner,
    amateur,
    intermediate,
    professional,
  ];

  static String displayName(String level) {
    switch (level) {
      case beginner:
        return 'Beginner';
      case amateur:
        return 'Amateur';
      case intermediate:
        return 'Intermediate';
      case professional:
        return 'Professional';
      default:
        return level;
    }
  }
}

/// Enum-like class for activity types
class ActivityType {
  static const String walking = 'WALKING';
  static const String hiking = 'HIKING';
  static const String leisurely = 'LEISURELY';
  static const String competitive = 'COMPETITIVE';

  static const List<String> all = [walking, hiking, leisurely, competitive];

  static String displayName(String type) {
    switch (type) {
      case walking:
        return 'Walking';
      case hiking:
        return 'Hiking';
      case leisurely:
        return 'Leisurely Running';
      case competitive:
        return 'Competitive Running';
      default:
        return type;
    }
  }
}

/// Enum-like class for intensity preferences
class IntensityPreference {
  static const String highIntensity = 'HIGH_INTENSITY';
  static const String steadyState = 'STEADY_STATE';

  static const List<String> all = [highIntensity, steadyState];

  static String displayName(String intensity) {
    switch (intensity) {
      case highIntensity:
        return 'High-Intensity/Sprints';
      case steadyState:
        return 'Steady Long-Distance';
      default:
        return intensity;
    }
  }
}

/// Enum-like class for social vibe
class SocialVibe {
  static const String silent = 'SILENT';
  static const String social = 'SOCIAL';

  static const List<String> all = [silent, social];

  static String displayName(String vibe) {
    switch (vibe) {
      case silent:
        return 'Silent Runner';
      case social:
        return 'Social Runner';
      default:
        return vibe;
    }
  }

  static String description(String vibe) {
    switch (vibe) {
      case silent:
        return 'Focused, prefer no talking';
      case social:
        return 'Enjoy chatting while running';
      default:
        return '';
    }
  }
}

/// Enum-like class for motivation types
class MotivationType {
  static const String mentalHealth = 'MENTAL_HEALTH';
  static const String weightLoss = 'WEIGHT_LOSS';
  static const String training = 'TRAINING';
  static const String socializing = 'SOCIALIZING';

  static const List<String> all = [
    mentalHealth,
    weightLoss,
    training,
    socializing,
  ];

  static String displayName(String type) {
    switch (type) {
      case mentalHealth:
        return 'Mental Health';
      case weightLoss:
        return 'Weight Loss';
      case training:
        return 'Training for Event';
      case socializing:
        return 'Socializing';
      default:
        return type;
    }
  }
}

/// Enum-like class for coaching styles
class CoachingStyle {
  static const String pusher = 'PUSHER';
  static const String companion = 'COMPANION';

  static const List<String> all = [pusher, companion];

  static String displayName(String style) {
    switch (style) {
      case pusher:
        return 'Pusher';
      case companion:
        return 'Companion';
      default:
        return style;
    }
  }

  static String description(String style) {
    switch (style) {
      case pusher:
        return 'Encourage others to go faster';
      case companion:
        return 'Match the other\'s energy';
      default:
        return '';
    }
  }
}

/// Enum-like class for music preferences
class MusicPreference {
  static const String headphones = 'HEADPHONES';
  static const String nature = 'NATURE';

  static const List<String> all = [headphones, nature];

  static String displayName(String pref) {
    switch (pref) {
      case headphones:
        return 'With Headphones';
      case nature:
        return 'Sounds of Nature';
      default:
        return pref;
    }
  }
}
