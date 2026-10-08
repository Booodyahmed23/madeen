import '../../domain/entities/course_section.dart';
import 'lesson_model.dart';

class CourseSectionModel {
  const CourseSectionModel({
    required this.id,
    required this.courseId,
    required this.title,
    required this.order,
    required this.lessons,
  });

  factory CourseSectionModel.fromJson(Map<String, dynamic> json) {
    return CourseSectionModel(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      title: json['title'] as String,
      order: (json['order'] as num).toInt(),
      lessons: (json['lessons'] as List)
          .map((l) => LessonModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String courseId;
  final String title;
  final int order;
  final List<LessonModel> lessons;

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'title': title,
    'order': order,
    'lessons': lessons.map((l) => l.toJson()).toList(),
  };

  CourseSection toEntity() => CourseSection(
    id: id,
    courseId: courseId,
    title: title,
    order: order,
    lessons: lessons.map((l) => l.toEntity()).toList(),
  );
}
