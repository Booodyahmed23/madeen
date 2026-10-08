import 'course_enrollment.dart';
import 'course_section.dart';
import 'lesson.dart';

/// A "record once, serve many" master course — per
/// `docs/ARCHITECTURE.md` §13.1, authored once; access for many
/// students is entirely an Entitlement concern (not implemented in this
/// project yet), never a content-duplication concern. Carries every
/// [CourseSection]/[Lesson] in one fetch — unlike Curriculum's own
/// Program→Part→Unit→SubUnit→Topic tree, a course's tree is shallow and
/// small enough that fetching it level-by-level would only add round
/// trips, not real pagination value (see `COURSE_API_REQUIREMENTS.md`).
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailAssetId,
    required this.sections,
  });

  final String id;
  final String title;
  final String description;

  /// An opaque reference to a thumbnail image — same "never a vendor URL,
  /// just a reference" rule as [Lesson.videoAssetId]. `null` renders a
  /// plain placeholder.
  final String? thumbnailAssetId;

  final List<CourseSection> sections;

  int get totalLessons =>
      sections.fold(0, (sum, section) => sum + section.lessons.length);

  Duration get totalDuration => sections.fold(
    Duration.zero,
    (sum, section) =>
        sum +
        section.lessons.fold(
          Duration.zero,
          (lessonSum, lesson) => lessonSum + lesson.duration,
        ),
  );

  /// Every lesson across every section, in the order a student would
  /// naturally watch them — backs Lesson Details' previous/next
  /// navigation without a separate "flattened lesson list" fetch.
  List<Lesson> get lessonsInOrder {
    final orderedSections = [...sections]
      ..sort((a, b) => a.order.compareTo(b.order));
    return orderedSections.expand((section) {
      final orderedLessons = [...section.lessons]
        ..sort((a, b) => a.order.compareTo(b.order));
      return orderedLessons;
    }).toList();
  }

  /// 0–100. Guards the no-lessons edge case the same way
  /// `PerformanceOverview.overallAccuracyPercent` guards zero attempts.
  double completionPercent(CourseEnrollment enrollment) {
    if (totalLessons == 0) return 0;
    return (enrollment.completedLessonIds.length / totalLessons) * 100;
  }
}
