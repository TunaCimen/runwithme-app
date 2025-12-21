/// State model matching the database schema
class State {
  final int id;
  final String name;
  final int countryId;
  final String countryCode;
  final String? fipsCode;
  final String? iso2;
  final String? iso31662;
  final String? type;
  final int? level;
  final int? parentId;
  final double? latitude;
  final double? longitude;
  final String? timezone;
  final String? wikiDataId;

  const State({
    required this.id,
    required this.name,
    required this.countryId,
    required this.countryCode,
    this.fipsCode,
    this.iso2,
    this.iso31662,
    this.type,
    this.level,
    this.parentId,
    this.latitude,
    this.longitude,
    this.timezone,
    this.wikiDataId,
  });

  factory State.fromJson(Map<String, dynamic> json) {
    return State(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      countryId:
          (json['countryId'] as num?)?.toInt() ??
          (json['country_id'] as num).toInt(),
      countryCode:
          json['countryCode'] as String? ?? json['country_code'] as String,
      fipsCode: json['fipsCode'] as String? ?? json['fips_code'] as String?,
      iso2: json['iso2'] as String?,
      iso31662: json['iso31662'] as String? ?? json['iso3166_2'] as String?,
      type: json['type'] as String?,
      level: (json['level'] as num?)?.toInt(),
      parentId:
          (json['parentId'] as num?)?.toInt() ??
          (json['parent_id'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezone: json['timezone'] as String?,
      wikiDataId: json['wikiDataId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'countryId': countryId,
      'countryCode': countryCode,
      'fipsCode': fipsCode,
      'iso2': iso2,
      'iso31662': iso31662,
      'type': type,
      'level': level,
      'parentId': parentId,
      'latitude': latitude,
      'longitude': longitude,
      'timezone': timezone,
      'wikiDataId': wikiDataId,
    };
  }

  @override
  String toString() {
    return 'State(id: $id, name: $name, countryCode: $countryCode)';
  }

  State copyWith({
    int? id,
    String? name,
    int? countryId,
    String? countryCode,
    String? fipsCode,
    String? iso2,
    String? iso31662,
    String? type,
    int? level,
    int? parentId,
    double? latitude,
    double? longitude,
    String? timezone,
    String? wikiDataId,
  }) {
    return State(
      id: id ?? this.id,
      name: name ?? this.name,
      countryId: countryId ?? this.countryId,
      countryCode: countryCode ?? this.countryCode,
      fipsCode: fipsCode ?? this.fipsCode,
      iso2: iso2 ?? this.iso2,
      iso31662: iso31662 ?? this.iso31662,
      type: type ?? this.type,
      level: level ?? this.level,
      parentId: parentId ?? this.parentId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      wikiDataId: wikiDataId ?? this.wikiDataId,
    );
  }
}
