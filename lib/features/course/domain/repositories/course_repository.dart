import '../../../../core/error/result.dart';
import '../entities/course.dart';
import '../entities/course_enrollment.dart';

/// The mobile app's only window onto Course — presentation code depends
/// on this interface, never on a concrete data source (see
/// COURSE_API_REQUIREMENTS.md at the repo root of mobile/ for the proposed
/// backend contract this mirrors).
abstract class CourseRepository {
  /// [languageCode] is `'en'` or `'ar'` — authored course content is
  /// bilingual (per `docs/ARCHITECTURE.md` §19's `_i18n` convention for
  /// authored content), so the caller's current effective UI language
  /// decides which copy comes back, the same way
  /// `AiAnalysisRepository.getOverallAnalysis` and
  /// `TutorRepository.sendMessage` already take it explicitly.
  Future<Result<List<Course>>> getCourses({required String languageCode});

  /// Progress only — never an access decision (see [CourseEnrollment]'s
  /// own doc comment). Created lazily with no completed lessons if this
  /// student has never opened anything in this course yet.
  Future<Result<CourseEnrollment>> getEnrollment(String courseId);

  Future<Result<CourseEnrollment>> setLessonCompleted({
    required String courseId,
    required String lessonId,
    required bool completed,
  });

  /// Records "the student most recently opened this lesson" — backs a
  /// future "Continue" affordance on Course Details. Never affects
  /// [CourseEnrollment.completedLessonIds].
  Future<Result<CourseEnrollment>> setLastAccessedLesson({
    required String courseId,
    required String lessonId,
  });
}
