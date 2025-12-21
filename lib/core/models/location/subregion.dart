/// Subregion model matching the database schema
class Subregion {
  final int id;
  final String name;
  final int regionId;
  final int flag;
  final String? wikiDataId;

  const Subregion({
    required this.id,
    required this.name,
    required this.regionId,
    this.flag = 1,
    this.wikiDataId,
  });

  factory Subregion.fromJson(Map<String, dynamic> json) {
    return Subregion(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      regionId:
          (json['regionId'] as num?)?.toInt() ??
          (json['region_id'] as num).toInt(),
      flag: (json['flag'] as num?)?.toInt() ?? 1,
      wikiDataId: json['wikiDataId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'regionId': regionId,
      'flag': flag,
      'wikiDataId': wikiDataId,
    };
  }

  @override
  String toString() {
    return 'Subregion(id: $id, name: $name, regionId: $regionId)';
  }

  Subregion copyWith({
    int? id,
    String? name,
    int? regionId,
    int? flag,
    String? wikiDataId,
  }) {
    return Subregion(
      id: id ?? this.id,
      name: name ?? this.name,
      regionId: regionId ?? this.regionId,
      flag: flag ?? this.flag,
      wikiDataId: wikiDataId ?? this.wikiDataId,
    );
  }
}
