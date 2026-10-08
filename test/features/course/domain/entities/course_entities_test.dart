import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/course/domain/entities/course.dart';
import 'package:mobile/features/course/domain/entities/course_enrollment.dart';
import 'package:mobile/features/course/domain/entities/course_section.dart';
import 'package:mobile/features/course/domain/entities/lesson.dart';

Lesson _lesson(String id, {required int order, Duration? duration}) => Lesson(
  id: id,
  sectionId: 'section-1',
  title: 'Lesson $id',
  description: 'Description $id',
  duration: duration ?? const Duration(minutes: 5),
  order: order,
  videoAssetId: 'video-$id',
);

void main() {
  group('CourseEnrollment.copyWith', () {
    test('keeps existing fields when nothing is overridden', () {
      const enrollment = CourseEnrollment(
        courseId: 'course-1',
        completedLessonIds: {'lesson-1'},
        lastAccessedLessonId: 'lesson-1',
      );
      final copy = enrollment.copyWith();

      expect(copy.courseId, 'course-1');
      expect(copy.completedLessonIds, {'lesson-1'});
      expect(copy.lastAccessedLessonId, 'lesson-1');
    });

    test('overrides only the fields passed', () {
      const enrollment = CourseEnrollment(courseId: 'course-1');
      final copy = enrollment.copyWith(
        completedLessonIds: {'lesson-1', 'lesson-2'},
        lastAccessedLessonId: 'lesson-2',
      );

      expect(copy.completedLessonIds, {'lesson-1', 'lesson-2'});
      expect(copy.lastAccessedLessonId, 'lesson-2');
    });
  });

  group('Course', () {
    final course = Course(
      id: 'course-1',
      title: 'Course 1',
      description: 'Description',
      sections: [
        CourseSection(
          id: 'section-2',
          courseId: 'course-1',
          title: 'Section 2',
          order: 1,
          lessons: [
            _lesson('l3', order: 1, duration: const Duration(minutes: 10)),
            _lesson('l2', order: 0, duration: const Duration(minutes: 8)),
          ],
        ),
        CourseSection(
          id: 'section-1',
          courseId: 'course-1',
          title: 'Section 1',
          order: 0,
          lessons: [
            _lesson('l1', order: 0, duration: const Duration(minutes: 7)),
          ],
        ),
      ],
    );

    test('totalLessons counts across every section', () {
      expect(course.totalLessons, 3);
    });

    test('totalDuration sums every lesson across every section', () {
      expect(course.totalDuration, const Duration(minutes: 25));
    });

    test('lessonsInOrder sorts sections then lessons within each section', () {
      expect(course.lessonsInOrder.map((l) => l.id), ['l1', 'l2', 'l3']);
    });

    test('completionPercent is 0 when no lessons are completed', () {
      const enrollment = CourseEnrollment(courseId: 'course-1');
      expect(course.completionPercent(enrollment), 0);
    });

    test('completionPercent reflects the fraction of completed lessons', () {
      const enrollment = CourseEnrollment(
        courseId: 'course-1',
        completedLessonIds: {'l1', 'l2'},
      );
      expect(course.completionPercent(enrollment), closeTo(66.67, 0.01));
    });

    test('completionPercent is 100 when every lesson is completed', () {
      const enrollment = CourseEnrollment(
        courseId: 'course-1',
        completedLessonIds: {'l1', 'l2', 'l3'},
      );
      expect(course.completionPercent(enrollment), 100);
    });

    test('completionPercent guards the no-lessons edge case', () {
      final empty = Course(
        id: 'course-empty',
        title: 'Empty',
        description: 'No sections',
        sections: const [],
      );
      expect(
        empty.completionPercent(
          const CourseEnrollment(courseId: 'course-empty'),
        ),
        0,
      );
    });
  });
}
