import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/course/data/models/course_enrollment_model.dart';
import 'package:mobile/features/course/data/models/course_model.dart';
import 'package:mobile/features/course/data/models/course_section_model.dart';
import 'package:mobile/features/course/data/models/lesson_model.dart';

void main() {
  group('LessonModel', () {
    test('fromJson parses every field', () {
      final model = LessonModel.fromJson({
        'id': 'lesson-1',
        'sectionId': 'section-1',
        'title': 'Intro',
        'description': 'Desc',
        'durationSeconds': 125,
        'order': 2,
        'videoAssetId': 'video-1',
      });

      expect(model.id, 'lesson-1');
      expect(model.sectionId, 'section-1');
      expect(model.title, 'Intro');
      expect(model.description, 'Desc');
      expect(model.durationSeconds, 125);
      expect(model.order, 2);
      expect(model.videoAssetId, 'video-1');
    });

    test('toJson round-trips through fromJson', () {
      const model = LessonModel(
        id: 'lesson-1',
        sectionId: 'section-1',
        title: 'Intro',
        description: 'Desc',
        durationSeconds: 125,
        order: 2,
        videoAssetId: 'video-1',
      );

      final roundTripped = LessonModel.fromJson(model.toJson());
      expect(roundTripped.toJson(), model.toJson());
    });

    test('toEntity converts durationSeconds into a Duration', () {
      const model = LessonModel(
        id: 'lesson-1',
        sectionId: 'section-1',
        title: 'Intro',
        description: 'Desc',
        durationSeconds: 90,
        order: 0,
        videoAssetId: 'video-1',
      );

      expect(model.toEntity().duration, const Duration(seconds: 90));
    });
  });

  group('CourseSectionModel', () {
    test('fromJson parses nested lessons', () {
      final model = CourseSectionModel.fromJson({
        'id': 'section-1',
        'courseId': 'course-1',
        'title': 'Section 1',
        'order': 0,
        'lessons': [
          {
            'id': 'lesson-1',
            'sectionId': 'section-1',
            'title': 'Intro',
            'description': 'Desc',
            'durationSeconds': 60,
            'order': 0,
            'videoAssetId': 'video-1',
          },
        ],
      });

      expect(model.lessons, hasLength(1));
      expect(model.lessons.first.id, 'lesson-1');
    });

    test('toEntity maps every lesson to its domain entity', () {
      final model = CourseSectionModel.fromJson({
        'id': 'section-1',
        'courseId': 'course-1',
        'title': 'Section 1',
        'order': 0,
        'lessons': [
          {
            'id': 'lesson-1',
            'sectionId': 'section-1',
            'title': 'Intro',
            'description': 'Desc',
            'durationSeconds': 60,
            'order': 0,
            'videoAssetId': 'video-1',
          },
        ],
      });
      final entity = model.toEntity();

      expect(entity.id, 'section-1');
      expect(entity.lessons, hasLength(1));
      expect(entity.lessons.first.title, 'Intro');
    });
  });

  group('CourseModel', () {
    test('fromJson treats a missing thumbnailAssetId as absent', () {
      final model = CourseModel.fromJson({
        'id': 'course-1',
        'title': 'Course 1',
        'description': 'Desc',
        'sections': <Map<String, dynamic>>[],
      });

      expect(model.thumbnailAssetId, isNull);
      expect(model.sections, isEmpty);
    });

    test('toEntity maps every section to its domain entity', () {
      final model = CourseModel.fromJson({
        'id': 'course-1',
        'title': 'Course 1',
        'description': 'Desc',
        'sections': [
          {
            'id': 'section-1',
            'courseId': 'course-1',
            'title': 'Section 1',
            'order': 0,
            'lessons': <Map<String, dynamic>>[],
          },
        ],
      });
      final entity = model.toEntity();

      expect(entity.id, 'course-1');
      expect(entity.sections, hasLength(1));
      expect(entity.sections.first.title, 'Section 1');
    });
  });

  group('CourseEnrollmentModel', () {
    test('fromJson defaults completedLessonIds to empty when absent', () {
      final model = CourseEnrollmentModel.fromJson({'courseId': 'course-1'});

      expect(model.completedLessonIds, isEmpty);
      expect(model.lastAccessedLessonId, isNull);
    });

    test('fromJson parses a populated set and last-accessed lesson', () {
      final model = CourseEnrollmentModel.fromJson({
        'courseId': 'course-1',
        'completedLessonIds': ['lesson-1', 'lesson-2'],
        'lastAccessedLessonId': 'lesson-2',
      });

      expect(model.completedLessonIds, {'lesson-1', 'lesson-2'});
      expect(model.lastAccessedLessonId, 'lesson-2');
    });

    test('toEntity maps every field unchanged', () {
      final model = CourseEnrollmentModel.fromJson({
        'courseId': 'course-1',
        'completedLessonIds': ['lesson-1'],
        'lastAccessedLessonId': 'lesson-1',
      });
      final entity = model.toEntity();

      expect(entity.courseId, 'course-1');
      expect(entity.completedLessonIds, {'lesson-1'});
      expect(entity.lastAccessedLessonId, 'lesson-1');
    });
  });
}
