import 'route_point.dart';

/// Model representing a running session
class RunSession {
  final int id;
  final String? runnerId;
  final int? routeId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceM;
  final int durationS;
  final double? avgPaceSecPerKm;
  final double? caloriesBurned;
  final List<RunPoint> trackPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  RunSession({
    required this.id,
    this.runnerId,
    this.routeId,
    required this.startTime,
    this.endTime,
    required this.distanceM,
    required this.durationS,
    this.avgPaceSecPerKm,
    this.caloriesBurned,
    this.trackPoints = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    return RunSession(
      id: json['id'] ?? 0,
      runnerId: json['runnerId'] ?? json['runner_id'],
      routeId: json['routeId'] ?? json['route_id'],
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : (json['start_time'] != null
              ? DateTime.parse(json['start_time'])
              : DateTime.now()),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'])
          : (json['end_time'] != null ? DateTime.parse(json['end_time']) : null),
      distanceM: (json['distanceM'] ?? json['distance_m'] ?? 0).toDouble(),
      durationS: json['durationS'] ?? json['duration_s'] ?? 0,
      avgPaceSecPerKm: json['avgPaceSecPerKm']?.toDouble() ??
          json['avg_pace_sec_per_km']?.toDouble(),
      caloriesBurned: json['caloriesBurned']?.toDouble() ??
          json['calories_burned']?.toDouble(),
      trackPoints: (json['trackPoints'] as List<dynamic>?)
              ?.map((p) => RunPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (runnerId != null) 'runnerId': runnerId,
      if (routeId != null) 'routeId': routeId,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'distanceM': distanceM,
      'durationS': durationS,
      if (avgPaceSecPerKm != null) 'avgPaceSecPerKm': avgPaceSecPerKm,
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      'trackPoints': trackPoints.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  RunSession copyWith({
    int? id,
    String? runnerId,
    int? routeId,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceM,
    int? durationS,
    double? avgPaceSecPerKm,
    double? caloriesBurned,
    List<RunPoint>? trackPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RunSession(
      id: id ?? this.id,
      runnerId: runnerId ?? this.runnerId,
      routeId: routeId ?? this.routeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceM: distanceM ?? this.distanceM,
      durationS: durationS ?? this.durationS,
      avgPaceSecPerKm: avgPaceSecPerKm ?? this.avgPaceSecPerKm,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      trackPoints: trackPoints ?? this.trackPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get distance in kilometers
  double get distanceKm => distanceM / 1000;

  /// Get formatted distance string
  String get formattedDistance {
    final km = distanceKm;
    if (km >= 1) {
      return '${km.toStringAsFixed(2)} km';
    }
    return '${distanceM.toInt()} m';
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = durationS ~/ 3600;
    final minutes = (durationS % 3600) ~/ 60;
    final seconds = durationS % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Get formatted pace string (min:sec per km)
  String get formattedPace {
    if (avgPaceSecPerKm == null || avgPaceSecPerKm == 0) {
      if (distanceM > 0 && durationS > 0) {
        final paceSecPerKm = durationS / distanceKm;
        final minutes = paceSecPerKm ~/ 60;
        final seconds = (paceSecPerKm % 60).toInt();
        return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
      }
      return '--:--/km';
    }
    final minutes = avgPaceSecPerKm! ~/ 60;
    final seconds = (avgPaceSecPerKm! % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  @override
  String toString() {
    return 'RunSession(id: $id, distance: $formattedDistance, duration: $formattedDuration)';
  }
}

/// Model representing a point in a run track
class RunPoint {
  final int id;
  final int runSessionId;
  final int seqNo;
  final double latitude;
  final double longitude;
  final double? elevationM;
  final double? speedMps;
  final DateTime timestamp;

  RunPoint({
    required this.id,
    required this.runSessionId,
    required this.seqNo,
    required this.latitude,
    required this.longitude,
    this.elevationM,
    this.speedMps,
    required this.timestamp,
  });

  factory RunPoint.fromJson(Map<String, dynamic> json) {
    return RunPoint(
      id: json['id'] ?? 0,
      runSessionId: json['runSessionId'] ?? json['run_session_id'] ?? 0,
      seqNo: json['seqNo'] ?? json['seq_no'] ?? 0,
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lon'] ?? 0).toDouble(),
      elevationM: json['elevationM']?.toDouble() ?? json['elevation_m']?.toDouble(),
      speedMps: json['speedMps']?.toDouble() ?? json['speed_mps']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'runSessionId': runSessionId,
      'seqNo': seqNo,
      'latitude': latitude,
      'longitude': longitude,
      if (elevationM != null) 'elevationM': elevationM,
      if (speedMps != null) 'speedMps': speedMps,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  RunPoint copyWith({
    int? id,
    int? runSessionId,
    int? seqNo,
    double? latitude,
    double? longitude,
    double? elevationM,
    double? speedMps,
    DateTime? timestamp,
  }) {
    return RunPoint(
      id: id ?? this.id,
      runSessionId: runSessionId ?? this.runSessionId,
      seqNo: seqNo ?? this.seqNo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationM: elevationM ?? this.elevationM,
      speedMps: speedMps ?? this.speedMps,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
