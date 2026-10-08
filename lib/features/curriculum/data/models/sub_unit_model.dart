import '../../domain/entities/sub_unit.dart';

class SubUnitModel {
  const SubUnitModel({
    required this.id,
    required this.unitId,
    required this.name,
    this.description,
    this.order = 0,
  });

  factory SubUnitModel.fromJson(Map<String, dynamic> json) {
    return SubUnitModel(
      id: json['id'] as String,
      unitId: json['unitId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String unitId;
  final String name;
  final String? description;
  final int order;

  SubUnit toEntity() => SubUnit(
    id: id,
    unitId: unitId,
    name: name,
    description: description,
    order: order,
  );
}
