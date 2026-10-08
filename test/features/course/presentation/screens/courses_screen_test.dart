import 'dart:async';

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
import 'package:mobile/features/course/presentation/screens/courses_screen.dart';
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
      title: 'Section 1',
      order: 0,
      lessons: [
        Lesson(
          id: 'lesson-1',
          sectionId: 'section-1',
          title: 'Intro',
          description: 'Desc',
          duration: const Duration(minutes: 9),
          order: 0,
          videoAssetId: 'video-1',
        ),
      ],
    ),
  ],
);

Widget _wrap(
  CourseRepository repository, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [courseRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CoursesScreen(),
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator while courses are being fetched', (
    tester,
  ) async {
    final repository = MockCourseRepository();
    final completer = Completer<Result<List<Course>>>();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const Result.success([]));
    await tester.pumpAndSettle();
  });

  testWidgets('shows each course once loaded, with lesson count and duration', (
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
    expect(find.textContaining('1 lesson'), findsOneWidget);
    expect(find.textContaining('1 lessons'), findsNothing);
    expect(find.textContaining('09:00'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no courses', (
    tester,
  ) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('No courses available yet.'), findsOneWidget);
  });

  testWidgets('shows a localized error message and a retry button on failure', (
    tester,
  ) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('retry re-fetches after a failure', (tester) async {
    final repository = MockCourseRepository();
    var callCount = 0;
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return const Result.failure(NetworkFailure());
          return Result.success([_course]);
        });
    when(() => repository.getEnrollment(any())).thenAnswer(
      (_) async => const Result.success(CourseEnrollment(courseId: 'course-1')),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('CMA Part 1 Video Course'), findsOneWidget);
    expect(callCount, 2);
  });

  testWidgets(
    'shows the sample-data banner, since the Course API is not available',
    (tester) async {
      final repository = MockCourseRepository();
      when(
        () => repository.getCourses(languageCode: any(named: 'languageCode')),
      ).thenAnswer((_) async => const Result.success([]));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Showing sample course content"),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders in Arabic (RTL) without crashing', (tester) async {
    final repository = MockCourseRepository();
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الدورات'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
