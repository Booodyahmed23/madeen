import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/course/data/datasources/course_mock_data_source.dart';

void main() {
  late CourseMockDataSource dataSource;

  setUp(() => dataSource = CourseMockDataSource());

  test('getCourses returns both CMA courses in English by default', () async {
    final courses = await dataSource.getCourses('en');

    expect(courses.map((c) => c.id), [
      'course-cma-part-1',
      'course-cma-part-2',
    ]);
    expect(courses.first.title, 'CMA Part 1 Video Course');
  });

  test('getCourses returns Arabic content for the ar language code', () async {
    final courses = await dataSource.getCourses('ar');

    expect(courses.first.title, 'الدورة المرئية لاختبار CMA الجزء الأول');
  });

  test(
    'getCourses falls back to English for an unknown language code',
    () async {
      final courses = await dataSource.getCourses('fr');

      expect(courses.first.title, 'CMA Part 1 Video Course');
    },
  );

  test(
    'getEnrollment lazily creates an empty enrollment for a new course',
    () async {
      final enrollment = await dataSource.getEnrollment('course-cma-part-1');

      expect(enrollment.courseId, 'course-cma-part-1');
      expect(enrollment.completedLessonIds, isEmpty);
      expect(enrollment.lastAccessedLessonId, isNull);
    },
  );

  test('setLessonCompleted(true) adds the lesson id and persists it', () async {
    await dataSource.setLessonCompleted(
      courseId: 'course-cma-part-1',
      lessonId: 'lesson-intro-budgeting',
      completed: true,
    );
    final enrollment = await dataSource.getEnrollment('course-cma-part-1');

    expect(enrollment.completedLessonIds, {'lesson-intro-budgeting'});
  });

  test(
    'setLessonCompleted(false) removes a previously-completed lesson id',
    () async {
      await dataSource.setLessonCompleted(
        courseId: 'course-cma-part-1',
        lessonId: 'lesson-intro-budgeting',
        completed: true,
      );
      await dataSource.setLessonCompleted(
        courseId: 'course-cma-part-1',
        lessonId: 'lesson-intro-budgeting',
        completed: false,
      );
      final enrollment = await dataSource.getEnrollment('course-cma-part-1');

      expect(enrollment.completedLessonIds, isEmpty);
    },
  );

  test(
    'setLastAccessedLesson records the lesson without touching completion',
    () async {
      await dataSource.setLessonCompleted(
        courseId: 'course-cma-part-1',
        lessonId: 'lesson-intro-budgeting',
        completed: true,
      );
      final updated = await dataSource.setLastAccessedLesson(
        courseId: 'course-cma-part-1',
        lessonId: 'lesson-flexible-budgets',
      );

      expect(updated.lastAccessedLessonId, 'lesson-flexible-budgets');
      expect(updated.completedLessonIds, {'lesson-intro-budgeting'});
    },
  );

  test('enrollment state is independent per course', () async {
    await dataSource.setLessonCompleted(
      courseId: 'course-cma-part-1',
      lessonId: 'lesson-intro-budgeting',
      completed: true,
    );
    final otherCourse = await dataSource.getEnrollment('course-cma-part-2');

    expect(otherCourse.completedLessonIds, isEmpty);
  });
}
