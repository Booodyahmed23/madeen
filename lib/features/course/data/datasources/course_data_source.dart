import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'course_mock_data_source.dart';
import '../models/course_enrollment_model.dart';
import '../models/course_model.dart';

/// Shape both a future `CourseRemoteDataSource` (real backend, once it
/// exists — see COURSE_API_REQUIREMENTS.md) and [CourseMockDataSource]
/// implement — mirrors every other feature's own datasource interface
/// exactly (`CurriculumDataSource`, `NotificationsDataSource`, ...).
abstract class CourseDataSource {
  Future<List<CourseModel>> getCourses(String languageCode);

  Future<CourseEnrollmentModel> getEnrollment(String courseId);

  Future<CourseEnrollmentModel> setLessonCompleted({
    required String courseId,
    required String lessonId,
    required bool completed,
  });

  Future<CourseEnrollmentModel> setLastAccessedLesson({
    required String courseId,
    required String lessonId,
  });
}

/// The single switch between real and sample Course data — see
/// AppConfig.isCourseApiAvailable and COURSE_API_REQUIREMENTS.md. Not
/// `autoDispose`: the mock datasource holds mutable in-memory enrollment
/// state that must survive across screens for the whole app session, same
/// reasoning as `notificationsDataSourceProvider`.
final courseDataSourceProvider = Provider<CourseDataSource>((ref) {
  // AppConfig.isCourseApiAvailable is intentionally not branched on yet —
  // there is no CourseRemoteDataSource to select until the backend
  // `Course` module exists (see that flag's own doc comment).
  return CourseMockDataSource();
});
