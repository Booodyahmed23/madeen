import '../../domain/entities/program.dart';

/// JSON shape for one Program node: `{ id, name, description|null, order,
/// isPublished, createdAt, updatedAt }` (contract §A2). Only this file and
/// its sibling models know these key names; everything else in the app
/// deals in the domain [Program] entity.
class ProgramModel {
  const ProgramModel({
    required this.id,
    required this.name,
    this.description,
    this.order = 0,
    this.isPublished = true,
  });

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isPublished: json['isPublished'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String? description;
  final int order;
  final bool isPublished;

  Program toEntity() => Program(
    id: id,
    name: name,
    description: description,
    order: order,
    isPublished: isPublished,
  );
}
