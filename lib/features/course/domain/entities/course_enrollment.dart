/// A student's progress through one [Course] — per `docs/ARCHITECTURE.md`
/// §13.3, this exists **purely for progress tracking** (last position, %
/// complete) and is never consulted to decide access; that check belongs
/// to Entitlement, which does not exist in this project yet (mobile or
/// backend) — see `COURSE_API_REQUIREMENTS.md`'s "Entitlement / access
/// status". A real backend creates this lazily the first time a
/// (already-entitled) student opens a lesson; the mock does the same —
/// see `CourseMockDataSource`'s own doc comment.
class CourseEnrollment {
  const CourseEnrollment({
    required this.courseId,
    this.completedLessonIds = const {},
    this.lastAccessedLessonId,
  });

  final String courseId;
  final Set<String> completedLessonIds;
  final String? lastAccessedLessonId;

  CourseEnrollment copyWith({
    Set<String>? completedLessonIds,
    String? lastAccessedLessonId,
  }) {
    return CourseEnrollment(
      courseId: courseId,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      lastAccessedLessonId: lastAccessedLessonId ?? this.lastAccessedLessonId,
    );
  }
}
