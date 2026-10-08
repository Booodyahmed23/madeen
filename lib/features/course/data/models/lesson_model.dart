import '../../domain/entities/lesson.dart';

class LessonModel {
  const LessonModel({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.description,
    required this.durationSeconds,
    required this.order,
    required this.videoAssetId,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as String,
      sectionId: json['sectionId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      order: (json['order'] as num).toInt(),
      videoAssetId: json['videoAssetId'] as String,
    );
  }

  final String id;
  final String sectionId;
  final String title;
  final String description;
  final int durationSeconds;
  final int order;
  final String videoAssetId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sectionId': sectionId,
    'title': title,
    'description': description,
    'durationSeconds': durationSeconds,
    'order': order,
    'videoAssetId': videoAssetId,
  };

  Lesson toEntity() => Lesson(
    id: id,
    sectionId: sectionId,
    title: title,
    description: description,
    duration: Duration(seconds: durationSeconds),
    order: order,
    videoAssetId: videoAssetId,
  );
}
