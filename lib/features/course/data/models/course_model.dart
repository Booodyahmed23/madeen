import '../../domain/entities/course.dart';
import 'course_section_model.dart';

class CourseModel {
  const CourseModel({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailAssetId,
    required this.sections,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      thumbnailAssetId: json['thumbnailAssetId'] as String?,
      sections: (json['sections'] as List)
          .map((s) => CourseSectionModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String? thumbnailAssetId;
  final List<CourseSectionModel> sections;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'thumbnailAssetId': thumbnailAssetId,
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  Course toEntity() => Course(
    id: id,
    title: title,
    description: description,
    thumbnailAssetId: thumbnailAssetId,
    sections: sections.map((s) => s.toEntity()).toList(),
  );
}
