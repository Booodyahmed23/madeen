import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import 'course_language_provider.dart';

/// Every course, in the student's current effective UI language —
/// re-fetches if that language changes, same reactive pattern
/// `performanceOverviewProvider` uses for its own filter dependency.
final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final languageCode = ref.watch(courseLanguageProvider);
  final result = await ref
      .watch(courseRepositoryProvider)
      .getCourses(languageCode: languageCode);
  return _unwrap(result);
});

/// One course looked up by id from whatever [coursesProvider] already
/// fetched — same "don't re-fetch, look up from the list already in
/// memory" rule `notificationByIdProvider` follows, since Course Details
/// is only ever reached from the Course list in this app.
final courseByIdProvider = Provider.family<Course?, String>((ref, courseId) {
  final courses = ref.watch(coursesProvider).value;
  if (courses == null) return null;
  for (final course in courses) {
    if (course.id == courseId) return course;
  }
  return null;
});

/// This student's progress through one course — independent of
/// [coursesProvider] (progress is per-student, content is shared), kept
/// `autoDispose.family` so each course's progress is fetched only while
/// something is actually watching it.
final courseEnrollmentProvider = FutureProvider.family
    .autoDispose<CourseEnrollment, String>((ref, courseId) async {
      final result = await ref
          .watch(courseRepositoryProvider)
          .getEnrollment(courseId);
      return _unwrap(result);
    });

/// `FutureProvider` wants a thrown error for its `AsyncError` state, not a
/// `Result.failure` — same seam as every other feature's own `_unwrap`.
T _unwrap<T>(Result<T> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
}
