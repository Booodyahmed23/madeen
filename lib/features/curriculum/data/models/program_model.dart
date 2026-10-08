import '../../domain/entities/program.dart';

/// JSON shape for one Program, per the proposed contract in
/// CURRICULUM_API_REQUIREMENTS.md (not yet implemented backend-side — see
/// that file). Only this file and its sibling models know these key names;
/// everything else in the app deals in the domain [Program] entity.
class ProgramModel {
  const ProgramModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.imageUrl,
    this.order = 0,
    this.isActive,
  });

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    return ProgramModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool?,
    );
  }

  final String id;
  final String name;
  final String code;
  final String? description;
  final String? imageUrl;
  final int order;
  final bool? isActive;

  Program toEntity() => Program(
    id: id,
    name: name,
    code: code,
    description: description,
    imageUrl: imageUrl,
    order: order,
    isActive: isActive,
  );
}
