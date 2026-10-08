import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/course/data/repositories/course_repository_impl.dart';
import 'package:mobile/features/course/domain/entities/course.dart';
import 'package:mobile/features/course/domain/entities/course_enrollment.dart';
import 'package:mobile/features/course/domain/entities/course_section.dart';
import 'package:mobile/features/course/domain/entities/lesson.dart';
import 'package:mobile/features/course/domain/repositories/course_repository.dart';
import 'package:mobile/features/course/presentation/screens/course_details_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockCourseRepository extends Mock implements CourseRepository {}

final _course = Course(
  id: 'course-1',
  title: 'CMA Part 1 Video Course',
  description: 'A structured video walkthrough.',
  sections: [
    CourseSection(
      id: 'section-1',
      courseId: 'course-1',
      title: 'Budgeting',
      order: 0,
      lessons: [
        Lesson(
          id: 'lesson-1',
          sectionId: 'section-1',
          title: 'Introduction to Budgeting',
          description: 'Desc',
          duration: const Duration(minutes: 9),
          order: 0,
          videoAssetId: 'video-1',
        ),
        Lesson(
          id: 'lesson-2',
          sectionId: 'section-1',
          title: 'Flexible Budgets',
          description: 'Desc',
          duration: const Duration(minutes: 12),
          order: 1,
          videoAssetId: 'video-2',
        ),
      ],
    ),
  ],
);

Widget _wrap(
  CourseRepository repository, {
  String courseId = 'course-1',
  Locale? locale,
}) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [courseRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CourseDetailsScreen(courseId: courseId),
    ),
  );
}

void main() {
  testWidgets('shows the course title, sections and lessons once loaded', (
    tester,
  ) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => Result.success([_course]));
    when(() => repository.getEnrollment(any())).thenAnswer(
      (_) async => const Result.success(CourseEnrollment(courseId: 'course-1')),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('CMA Part 1 Video Course'), findsOneWidget);
    expect(find.text('Budgeting'), findsOneWidget);
    expect(find.text('Introduction to Budgeting'), findsOneWidget);
    expect(find.text('Flexible Budgets'), findsOneWidget);
  });

  testWidgets('shows the completion progress bar reflecting enrollment', (
    tester,
  ) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => Result.success([_course]));
    when(() => repository.getEnrollment(any())).thenAnswer(
      (_) async => const Result.success(
        CourseEnrollment(
          courseId: 'course-1',
          completedLessonIds: {'lesson-1'},
        ),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('shows a not-found message for an unknown course id', (
    tester,
  ) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => Result.success([_course]));

    await tester.pumpWidget(_wrap(repository, courseId: 'unknown-course'));
    await tester.pumpAndSettle();

    expect(find.text('This course could not be found.'), findsOneWidget);
  });

  testWidgets('shows a localized error message on failure', (tester) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    // The localized sentence, not AppFailure.message's English default.
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).errorNetwork),
      findsOneWidget,
    );
    expect(find.text('Network error. Please try again.'), findsNothing);
  });

  testWidgets('the failure message follows the Arabic locale', (tester) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      find.text(lookupAppLocalizations(const Locale('ar')).errorNetwork),
      findsOneWidget,
    );
  });
}
