/// Country model matching the database schema
class Country {
  final int id;
  final String name;
  final String? iso3;
  final String? numericCode;
  final String? iso2;
  final String? capital;
  final String? region;
  final int? regionId;
  final String? subregion;
  final int? subregionId;
  final String? nationality;
  final double? latitude;
  final double? longitude;
  final String? emoji;
  final String? emojiU;
  final int flag;
  final String? wikiDataId;

  const Country({
    required this.id,
    required this.name,
    this.iso3,
    this.numericCode,
    this.iso2,
    this.capital,
    this.region,
    this.regionId,
    this.subregion,
    this.subregionId,
    this.nationality,
    this.latitude,
    this.longitude,
    this.emoji,
    this.emojiU,
    this.flag = 1,
    this.wikiDataId,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      iso3: json['iso3'] as String?,
      numericCode: json['numericCode'] as String? ?? json['numeric_code'] as String?,
      iso2: json['iso2'] as String?,
      capital: json['capital'] as String?,
      region: json['region'] as String?,
      regionId: (json['regionId'] as num?)?.toInt() ?? (json['region_id'] as num?)?.toInt(),
      subregion: json['subregion'] as String?,
      subregionId: (json['subregionId'] as num?)?.toInt() ?? (json['subregion_id'] as num?)?.toInt(),
      nationality: json['nationality'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      emoji: json['emoji'] as String?,
      emojiU: json['emojiU'] as String?,
      flag: (json['flag'] as num?)?.toInt() ?? 1,
      wikiDataId: json['wikiDataId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iso3': iso3,
      'numericCode': numericCode,
      'iso2': iso2,
      'capital': capital,
      'region': region,
      'regionId': regionId,
      'subregion': subregion,
      'subregionId': subregionId,
      'nationality': nationality,
      'latitude': latitude,
      'longitude': longitude,
      'emoji': emoji,
      'emojiU': emojiU,
      'flag': flag,
      'wikiDataId': wikiDataId,
    };
  }

  @override
  String toString() {
    return 'Country(id: $id, name: $name, iso2: $iso2)';
  }

  Country copyWith({
    int? id,
    String? name,
    String? iso3,
    String? numericCode,
    String? iso2,
    String? capital,
    String? region,
    int? regionId,
    String? subregion,
    int? subregionId,
    String? nationality,
    double? latitude,
    double? longitude,
    String? emoji,
    String? emojiU,
    int? flag,
    String? wikiDataId,
  }) {
    return Country(
      id: id ?? this.id,
      name: name ?? this.name,
      iso3: iso3 ?? this.iso3,
      numericCode: numericCode ?? this.numericCode,
      iso2: iso2 ?? this.iso2,
      capital: capital ?? this.capital,
      region: region ?? this.region,
      regionId: regionId ?? this.regionId,
      subregion: subregion ?? this.subregion,
      subregionId: subregionId ?? this.subregionId,
      nationality: nationality ?? this.nationality,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      emoji: emoji ?? this.emoji,
      emojiU: emojiU ?? this.emojiU,
      flag: flag ?? this.flag,
      wikiDataId: wikiDataId ?? this.wikiDataId,
    );
  }
}
