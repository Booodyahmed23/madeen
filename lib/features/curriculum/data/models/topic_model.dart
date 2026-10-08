import '../../domain/entities/topic.dart';

class TopicModel {
  const TopicModel({
    required this.id,
    required this.subUnitId,
    required this.name,
    this.description,
    this.order = 0,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['id'] as String,
      subUnitId: json['subUnitId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String subUnitId;
  final String name;
  final String? description;
  final int order;

  Topic toEntity() => Topic(
    id: id,
    subUnitId: subUnitId,
    name: name,
    description: description,
    order: order,
  );
}
