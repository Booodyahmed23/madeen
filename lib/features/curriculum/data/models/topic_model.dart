import '../../domain/entities/topic.dart';

class TopicModel {
  const TopicModel({
    required this.id,
    required this.subUnitId,
    required this.name,
    this.description,
    this.order = 0,
    this.publishedQuestionCount,
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: json['id'] as String,
      subUnitId: json['subUnitId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      // Only the tree endpoint includes `questionCounts`.
      publishedQuestionCount:
          ((json['questionCounts'] as Map<String, dynamic>?)?['PUBLISHED']
                  as num?)
              ?.toInt(),
    );
  }

  final String id;
  final String subUnitId;
  final String name;
  final String? description;
  final int order;
  final int? publishedQuestionCount;

  Topic toEntity() => Topic(
    id: id,
    subUnitId: subUnitId,
    name: name,
    description: description,
    order: order,
    publishedQuestionCount: publishedQuestionCount,
  );
}
