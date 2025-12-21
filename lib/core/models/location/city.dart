/// City model matching the database schema
class City {
  final int id;
  final String name;
  final int stateId;
  final String stateCode;
  final int countryId;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String? wikiDataId;

  const City({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateCode,
    required this.countryId,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    this.wikiDataId,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      stateId:
          (json['stateId'] as num?)?.toInt() ??
          (json['state_id'] as num).toInt(),
      stateCode: json['stateCode'] as String? ?? json['state_code'] as String,
      countryId:
          (json['countryId'] as num?)?.toInt() ??
          (json['country_id'] as num).toInt(),
      countryCode:
          json['countryCode'] as String? ?? json['country_code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      wikiDataId: json['wikiDataId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stateId': stateId,
      'stateCode': stateCode,
      'countryId': countryId,
      'countryCode': countryCode,
      'latitude': latitude,
      'longitude': longitude,
      'wikiDataId': wikiDataId,
    };
  }

  @override
  String toString() {
    return 'City(id: $id, name: $name, stateCode: $stateCode, countryCode: $countryCode)';
  }

  City copyWith({
    int? id,
    String? name,
    int? stateId,
    String? stateCode,
    int? countryId,
    String? countryCode,
    double? latitude,
    double? longitude,
    String? wikiDataId,
  }) {
    return City(
      id: id ?? this.id,
      name: name ?? this.name,
      stateId: stateId ?? this.stateId,
      stateCode: stateCode ?? this.stateCode,
      countryId: countryId ?? this.countryId,
      countryCode: countryCode ?? this.countryCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      wikiDataId: wikiDataId ?? this.wikiDataId,
    );
  }
}
