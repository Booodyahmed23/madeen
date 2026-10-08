import '../../domain/entities/part.dart';

class PartModel {
  const PartModel({
    required this.id,
    required this.programId,
    required this.name,
    this.description,
    this.order = 0,
  });

  factory PartModel.fromJson(Map<String, dynamic> json) {
    return PartModel(
      id: json['id'] as String,
      programId: json['programId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String programId;
  final String name;
  final String? description;
  final int order;

  Part toEntity() => Part(
    id: id,
    programId: programId,
    name: name,
    description: description,
    order: order,
  );
}
