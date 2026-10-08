import '../../domain/entities/unit.dart';

class UnitModel {
  const UnitModel({
    required this.id,
    required this.partId,
    required this.name,
    this.description,
    this.order = 0,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'] as String,
      partId: json['partId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String partId;
  final String name;
  final String? description;
  final int order;

  Unit toEntity() => Unit(
    id: id,
    partId: partId,
    name: name,
    description: description,
    order: order,
  );
}
