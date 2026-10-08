import 'lesson.dart';

/// One section inside a [Course] — a grouping of [Lesson]s, matching
/// `docs/ARCHITECTURE.md` §13's `Course → CourseSection → Lesson` model.
class CourseSection {
  const CourseSection({
    required this.id,
    required this.courseId,
    required this.title,
    required this.order,
    required this.lessons,
  });

  final String id;
  final String courseId;
  final String title;

  /// Position within the course — sections render in this order, never
  /// in fetch order.
  final int order;

  final List<Lesson> lessons;
}
