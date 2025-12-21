/// Model representing a running session
class RunSession {
  final int id;
  final String? userId;
  final int? routeId;
  final bool isPublic;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int movingTimeS;
  final double totalDistanceM;
  final double? elevationGainM;
  final double? avgPaceSecPerKm;
  final String? geomTrack;
  final List<RunPoint> points;
  final DateTime createdAt;

  RunSession({
    required this.id,
    this.userId,
    this.routeId,
    this.isPublic = false,
    required this.startedAt,
    this.endedAt,
    required this.movingTimeS,
    required this.totalDistanceM,
    this.elevationGainM,
    this.avgPaceSecPerKm,
    this.geomTrack,
    this.points = const [],
    required this.createdAt,
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    return RunSession(
      id: json['id'] ?? 0,
      userId:
          json['userId'] ??
          json['user_id'] ??
          json['runnerId'] ??
          json['runner_id'],
      routeId: json['routeId'] ?? json['route_id'],
      isPublic: json['isPublic'] ?? json['is_public'] ?? false,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : (json['started_at'] != null
                ? DateTime.parse(json['started_at'])
                : (json['startTime'] != null
                      ? DateTime.parse(json['startTime'])
                      : DateTime.now())),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'])
          : (json['ended_at'] != null
                ? DateTime.parse(json['ended_at'])
                : (json['endTime'] != null
                      ? DateTime.parse(json['endTime'])
                      : null)),
      movingTimeS:
          json['movingTimeS'] ??
          json['moving_time_s'] ??
          json['durationS'] ??
          json['duration_s'] ??
          0,
      totalDistanceM:
          (json['totalDistanceM'] ??
                  json['total_distance_m'] ??
                  json['distanceM'] ??
                  json['distance_m'] ??
                  0)
              .toDouble(),
      elevationGainM:
          json['elevationGainM']?.toDouble() ??
          json['elevation_gain_m']?.toDouble(),
      avgPaceSecPerKm:
          json['avgPaceSecPerKm']?.toDouble() ??
          json['avg_pace_sec_per_km']?.toDouble(),
      geomTrack: json['geomTrack'] ?? json['geom_track'],
      points:
          (json['points'] as List<dynamic>?)
              ?.map((p) => RunPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          (json['trackPoints'] as List<dynamic>?)
              ?.map((p) => RunPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'])
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'userId': userId,
      if (routeId != null) 'routeId': routeId,
      'isPublic': isPublic,
      'startedAt': startedAt.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
      'movingTimeS': movingTimeS,
      'totalDistanceM': totalDistanceM,
      if (elevationGainM != null) 'elevationGainM': elevationGainM,
      if (avgPaceSecPerKm != null) 'avgPaceSecPerKm': avgPaceSecPerKm,
      if (geomTrack != null) 'geomTrack': geomTrack,
      'points': points.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  RunSession copyWith({
    int? id,
    String? userId,
    int? routeId,
    bool? isPublic,
    DateTime? startedAt,
    DateTime? endedAt,
    int? movingTimeS,
    double? totalDistanceM,
    double? elevationGainM,
    double? avgPaceSecPerKm,
    String? geomTrack,
    List<RunPoint>? points,
    DateTime? createdAt,
  }) {
    return RunSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      routeId: routeId ?? this.routeId,
      isPublic: isPublic ?? this.isPublic,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      movingTimeS: movingTimeS ?? this.movingTimeS,
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      avgPaceSecPerKm: avgPaceSecPerKm ?? this.avgPaceSecPerKm,
      geomTrack: geomTrack ?? this.geomTrack,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get distance in kilometers
  double get distanceKm => totalDistanceM / 1000;

  /// Get formatted distance string
  String get formattedDistance {
    final km = distanceKm;
    if (km >= 1) {
      return '${km.toStringAsFixed(2)} km';
    }
    return '${totalDistanceM.toInt()} m';
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = movingTimeS ~/ 3600;
    final minutes = (movingTimeS % 3600) ~/ 60;
    final seconds = movingTimeS % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Get formatted duration string (compact HH:MM:SS format)
  String get formattedDurationCompact {
    final hours = movingTimeS ~/ 3600;
    final minutes = (movingTimeS % 3600) ~/ 60;
    final seconds = movingTimeS % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted pace string (min:sec per km)
  String get formattedPace {
    if (avgPaceSecPerKm == null || avgPaceSecPerKm == 0) {
      if (totalDistanceM > 0 && movingTimeS > 0) {
        final paceSecPerKm = movingTimeS / distanceKm;
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

  /// Check if session is still active (not ended)
  bool get isActive => endedAt == null;

  /// Get formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(startedAt);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(startedAt)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(startedAt)}';
    } else if (difference.inDays < 7) {
      return '${_getDayName(startedAt.weekday)} at ${_formatTime(startedAt)}';
    } else {
      return '${startedAt.day}/${startedAt.month}/${startedAt.year}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  /// Get start point from track if available
  RunPoint? get startPoint => points.isNotEmpty ? points.first : null;

  /// Get end point from track if available
  RunPoint? get endPoint => points.isNotEmpty ? points.last : null;

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
      elevationM:
          json['elevationM']?.toDouble() ?? json['elevation_m']?.toDouble(),
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
