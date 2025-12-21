/// User statistics model for running metrics
class UserStatistics {
  final int totalRuns;
  final double totalDistanceKm;
  final String? averagePace;
  final double averageDistancePerRunKm;
  final double runsPerWeek;
  final double kmPerWeek;
  final double allTimeDistanceKm;
  final int allTimeTotalRuns;
  final int? periodDays;

  const UserStatistics({
    this.totalRuns = 0,
    this.totalDistanceKm = 0,
    this.averagePace,
    this.averageDistancePerRunKm = 0,
    this.runsPerWeek = 0,
    this.kmPerWeek = 0,
    this.allTimeDistanceKm = 0,
    this.allTimeTotalRuns = 0,
    this.periodDays,
  });

  factory UserStatistics.fromJson(Map<String, dynamic> json) {
    return UserStatistics(
      totalRuns: (json['totalRuns'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      averagePace: json['averagePace'] as String?,
      averageDistancePerRunKm:
          (json['averageDistancePerRunKm'] as num?)?.toDouble() ?? 0,
      runsPerWeek: (json['runsPerWeek'] as num?)?.toDouble() ?? 0,
      kmPerWeek: (json['kmPerWeek'] as num?)?.toDouble() ?? 0,
      allTimeDistanceKm: (json['allTimeDistanceKm'] as num?)?.toDouble() ?? 0,
      allTimeTotalRuns: (json['allTimeTotalRuns'] as num?)?.toInt() ?? 0,
      periodDays: (json['periodDays'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRuns': totalRuns,
      'totalDistanceKm': totalDistanceKm,
      'averagePace': averagePace,
      'averageDistancePerRunKm': averageDistancePerRunKm,
      'runsPerWeek': runsPerWeek,
      'kmPerWeek': kmPerWeek,
      'allTimeDistanceKm': allTimeDistanceKm,
      'allTimeTotalRuns': allTimeTotalRuns,
      'periodDays': periodDays,
    };
  }

  UserStatistics copyWith({
    int? totalRuns,
    double? totalDistanceKm,
    String? averagePace,
    double? averageDistancePerRunKm,
    double? runsPerWeek,
    double? kmPerWeek,
    double? allTimeDistanceKm,
    int? allTimeTotalRuns,
    int? periodDays,
  }) {
    return UserStatistics(
      totalRuns: totalRuns ?? this.totalRuns,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      averagePace: averagePace ?? this.averagePace,
      averageDistancePerRunKm:
          averageDistancePerRunKm ?? this.averageDistancePerRunKm,
      runsPerWeek: runsPerWeek ?? this.runsPerWeek,
      kmPerWeek: kmPerWeek ?? this.kmPerWeek,
      allTimeDistanceKm: allTimeDistanceKm ?? this.allTimeDistanceKm,
      allTimeTotalRuns: allTimeTotalRuns ?? this.allTimeTotalRuns,
      periodDays: periodDays ?? this.periodDays,
    );
  }

  @override
  String toString() {
    return 'UserStatistics(totalRuns: $totalRuns, totalDistanceKm: $totalDistanceKm, averagePace: $averagePace, periodDays: $periodDays)';
  }

  /// Check if statistics have any data
  bool get hasData =>
      totalRuns > 0 || totalDistanceKm > 0 || allTimeTotalRuns > 0;
}
