/// View model for profile statistics page
class ProfileStatsViewModel {
  final String userId;
  final int totalRuns;
  final double totalDistanceKm;
  final int currentStreak;
  final int longestStreak;
  final Duration totalDuration;
  final double averagePaceMinPerKm;
  final int totalAwards;
  final DateTime? lastRunDate;

  const ProfileStatsViewModel({
    required this.userId,
    this.totalRuns = 0,
    this.totalDistanceKm = 0.0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDuration = Duration.zero,
    this.averagePaceMinPerKm = 0.0,
    this.totalAwards = 0,
    this.lastRunDate,
  });

  /// Format total distance for display (e.g., "123.5 km")
  String get formattedDistance => '${totalDistanceKm.toStringAsFixed(1)} km';

  /// Format total duration (e.g., "12h 30m")
  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format average pace (e.g., "5:30 /km")
  String get formattedAveragePace {
    final minutes = averagePaceMinPerKm.floor();
    final seconds = ((averagePaceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Calculate average distance per run
  double get averageDistancePerRun {
    if (totalRuns == 0) return 0.0;
    return totalDistanceKm / totalRuns;
  }

  @override
  String toString() {
    return 'ProfileStatsViewModel(runs: $totalRuns, distance: $formattedDistance, streak: $currentStreak)';
  }

  ProfileStatsViewModel copyWith({
    String? userId,
    int? totalRuns,
    double? totalDistanceKm,
    int? currentStreak,
    int? longestStreak,
    Duration? totalDuration,
    double? averagePaceMinPerKm,
    int? totalAwards,
    DateTime? lastRunDate,
  }) {
    return ProfileStatsViewModel(
      userId: userId ?? this.userId,
      totalRuns: totalRuns ?? this.totalRuns,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalDuration: totalDuration ?? this.totalDuration,
      averagePaceMinPerKm: averagePaceMinPerKm ?? this.averagePaceMinPerKm,
      totalAwards: totalAwards ?? this.totalAwards,
      lastRunDate: lastRunDate ?? this.lastRunDate,
    );
  }

  factory ProfileStatsViewModel.fromJson(Map<String, dynamic> json) {
    return ProfileStatsViewModel(
      userId: json['userId'] as String? ?? '',
      totalRuns: (json['totalRuns'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      totalDuration: json['totalDurationSeconds'] != null
          ? Duration(seconds: (json['totalDurationSeconds'] as num).toInt())
          : Duration.zero,
      averagePaceMinPerKm: (json['averagePaceMinPerKm'] as num?)?.toDouble() ?? 0.0,
      totalAwards: (json['totalAwards'] as num?)?.toInt() ?? 0,
      lastRunDate: json['lastRunDate'] != null
          ? DateTime.parse(json['lastRunDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalRuns': totalRuns,
      'totalDistanceKm': totalDistanceKm,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalDurationSeconds': totalDuration.inSeconds,
      'averagePaceMinPerKm': averagePaceMinPerKm,
      'totalAwards': totalAwards,
      'lastRunDate': lastRunDate?.toIso8601String(),
    };
  }
}
