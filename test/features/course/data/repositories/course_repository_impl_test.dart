import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/features/course/data/datasources/course_data_source.dart';
import 'package:mobile/features/course/data/models/course_enrollment_model.dart';
import 'package:mobile/features/course/data/models/course_model.dart';
import 'package:mobile/features/course/data/repositories/course_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockCourseDataSource extends Mock implements CourseDataSource {}

void main() {
  late MockCourseDataSource dataSource;
  late CourseRepositoryImpl repository;

  setUp(() {
    dataSource = MockCourseDataSource();
    repository = CourseRepositoryImpl(dataSource);
  });

  group('getCourses', () {
    test('maps models to domain entities on success', () async {
      when(() => dataSource.getCourses(any())).thenAnswer(
        (_) async => [
          CourseModel.fromJson({
            'id': 'course-1',
            'title': 'Course 1',
            'description': 'Desc',
            'sections': <Map<String, dynamic>>[],
          }),
        ],
      );

      final result = await repository.getCourses(languageCode: 'en');

      expect(
        result.when(
          success: (courses) => courses.first.id,
          failure: (_) => null,
        ),
        'course-1',
      );
    });

    test('maps an unexpected exception to UnknownFailure', () async {
      when(() => dataSource.getCourses(any())).thenThrow(StateError('boom'));

      final result = await repository.getCourses(languageCode: 'en');

      expect(
        result.when(success: (_) => null, failure: (f) => f.runtimeType),
        UnknownFailure,
      );
    });
  });

  group('getEnrollment', () {
    test('maps the model to a domain entity on success', () async {
      when(() => dataSource.getEnrollment(any())).thenAnswer(
        (_) async => const CourseEnrollmentModel(courseId: 'course-1'),
      );

      final result = await repository.getEnrollment('course-1');

      expect(
        result.when(success: (e) => e.courseId, failure: (_) => null),
        'course-1',
      );
    });
  });

  group('setLessonCompleted', () {
    test('passes every argument through unchanged', () async {
      when(
        () => dataSource.setLessonCompleted(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
        ),
      ).thenAnswer(
        (_) async => const CourseEnrollmentModel(
          courseId: 'course-1',
          completedLessonIds: {'lesson-1'},
        ),
      );

      final result = await repository.setLessonCompleted(
        courseId: 'course-1',
        lessonId: 'lesson-1',
        completed: true,
      );

      verify(
        () => dataSource.setLessonCompleted(
          courseId: 'course-1',
          lessonId: 'lesson-1',
          completed: true,
        ),
      ).called(1);
      expect(
        result.when(success: (e) => e.completedLessonIds, failure: (_) => null),
        {'lesson-1'},
      );
    });
  });

  group('setLastAccessedLesson', () {
    test('maps a thrown exception to UnknownFailure', () async {
      when(
        () => dataSource.setLastAccessedLesson(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
        ),
      ).thenThrow(StateError('boom'));

      final result = await repository.setLastAccessedLesson(
        courseId: 'course-1',
        lessonId: 'lesson-1',
      );

      expect(
        result.when(success: (_) => null, failure: (f) => f.runtimeType),
        UnknownFailure,
      );
    });
  });
}
