/// Region model matching the database schema
class Region {
  final int id;
  final String name;
  final int flag;
  final String? wikiDataId;

  const Region({
    required this.id,
    required this.name,
    this.flag = 1,
    this.wikiDataId,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      flag: (json['flag'] as num?)?.toInt() ?? 1,
      wikiDataId: json['wikiDataId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'flag': flag, 'wikiDataId': wikiDataId};
  }

  @override
  String toString() {
    return 'Region(id: $id, name: $name)';
  }

  Region copyWith({int? id, String? name, int? flag, String? wikiDataId}) {
    return Region(
      id: id ?? this.id,
      name: name ?? this.name,
      flag: flag ?? this.flag,
      wikiDataId: wikiDataId ?? this.wikiDataId,
    );
  }
}
