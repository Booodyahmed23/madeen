import '../../domain/entities/course_enrollment.dart';

class CourseEnrollmentModel {
  const CourseEnrollmentModel({
    required this.courseId,
    this.completedLessonIds = const {},
    this.lastAccessedLessonId,
  });

  factory CourseEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return CourseEnrollmentModel(
      courseId: json['courseId'] as String,
      completedLessonIds: (json['completedLessonIds'] as List? ?? const [])
          .map((id) => id as String)
          .toSet(),
      lastAccessedLessonId: json['lastAccessedLessonId'] as String?,
    );
  }

  final String courseId;
  final Set<String> completedLessonIds;
  final String? lastAccessedLessonId;

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'completedLessonIds': completedLessonIds.toList(),
    'lastAccessedLessonId': lastAccessedLessonId,
  };

  CourseEnrollment toEntity() => CourseEnrollment(
    courseId: courseId,
    completedLessonIds: completedLessonIds,
    lastAccessedLessonId: lastAccessedLessonId,
  );
}
