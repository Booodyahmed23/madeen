import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/course/data/repositories/course_repository_impl.dart';
import 'package:mobile/features/course/domain/entities/course.dart';
import 'package:mobile/features/course/domain/entities/course_enrollment.dart';
import 'package:mobile/features/course/domain/entities/course_section.dart';
import 'package:mobile/features/course/domain/entities/lesson.dart';
import 'package:mobile/features/course/domain/repositories/course_repository.dart';
import 'package:mobile/features/course/presentation/screens/lesson_details_screen.dart';
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
          description: 'Why budgets exist.',
          duration: const Duration(minutes: 9),
          order: 0,
          videoAssetId: 'video-1',
        ),
        Lesson(
          id: 'lesson-2',
          sectionId: 'section-1',
          title: 'Flexible Budgets',
          description: 'Building a flexible budget.',
          duration: const Duration(minutes: 12),
          order: 1,
          videoAssetId: 'video-2',
        ),
      ],
    ),
  ],
);

/// A real (if tiny) [GoRouter] is needed here, not a bare [MaterialApp]:
/// Lesson Details' own prev/next buttons call `context.pushReplacement`
/// on itself, which throws without a GoRouter ancestor.
Widget _wrap(CourseRepository repository, {String lessonId = 'lesson-1'}) {
  final router = GoRouter(
    initialLocation: '/courses/course-1/lessons/$lessonId',
    routes: [
      GoRoute(
        path: '/courses/:courseId/lessons/:lessonId',
        builder: (context, state) => LessonDetailsScreen(
          courseId: state.pathParameters['courseId']!,
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
    ],
  );

  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [courseRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  late MockCourseRepository repository;
  late CourseEnrollment enrollment;

  setUp(() {
    repository = MockCourseRepository();
    enrollment = const CourseEnrollment(courseId: 'course-1');

    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => Result.success([_course]));
    when(() => repository.getEnrollment(any()))
        .thenAnswer((_) async => Result.success(enrollment));
    when(
      () => repository.setLastAccessedLesson(
        courseId: any(named: 'courseId'),
        lessonId: any(named: 'lessonId'),
      ),
    ).thenAnswer((invocation) async {
      enrollment = enrollment.copyWith(
        lastAccessedLessonId: invocation.namedArguments[#lessonId] as String,
      );
      return Result.success(enrollment);
    });
    when(
      () => repository.setLessonCompleted(
        courseId: any(named: 'courseId'),
        lessonId: any(named: 'lessonId'),
        completed: any(named: 'completed'),
      ),
    ).thenAnswer((invocation) async {
      final lessonId = invocation.namedArguments[#lessonId] as String;
      final completed = invocation.namedArguments[#completed] as bool;
      final ids = Set<String>.from(enrollment.completedLessonIds);
      completed ? ids.add(lessonId) : ids.remove(lessonId);
      enrollment = enrollment.copyWith(completedLessonIds: ids);
      return Result.success(enrollment);
    });
  });

  Future<void> pumpTall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows the lesson title, duration, description and video placeholder',
    (tester) async {
      await pumpTall(tester, _wrap(repository));

      expect(find.text('Introduction to Budgeting'), findsOneWidget);
      expect(find.text('Why budgets exist.'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(
        find.text(
          'Video will be available once a real video source is connected.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('records the last-accessed lesson once per screen open', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    verify(
      () => repository.setLastAccessedLesson(
        courseId: 'course-1',
        lessonId: 'lesson-1',
      ),
    ).called(1);
  });

  testWidgets(
    'toggling mark-as-completed calls the repository and updates the switch',
    (tester) async {
      await pumpTall(tester, _wrap(repository));

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      verify(
        () => repository.setLessonCompleted(
          courseId: 'course-1',
          lessonId: 'lesson-1',
          completed: true,
        ),
      ).called(1);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    },
  );

  testWidgets(
    'the previous button is disabled on the first lesson, next is enabled',
    (tester) async {
      await pumpTall(tester, _wrap(repository));

      final previousButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Previous'),
      );
      final nextButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );

      expect(previousButton.onPressed, isNull);
      expect(nextButton.onPressed, isNotNull);
    },
  );

  testWidgets('tapping Next navigates to the next lesson', (tester) async {
    await pumpTall(tester, _wrap(repository));

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('Flexible Budgets'), findsOneWidget);
    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(nextButton.onPressed, isNull); // last lesson
  });

  testWidgets('shows a not-found message for an unknown lesson id', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(repository, lessonId: 'unknown-lesson'));
    await tester.pumpAndSettle();

    expect(find.text('This lesson could not be found.'), findsOneWidget);
  });

  testWidgets('a load failure shows the localized message, not the raw one', (
    tester,
  ) async {
    when(() => repository.getCourses(languageCode: any(named: 'languageCode')))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text(lookupAppLocalizations(const Locale('en')).errorNetwork),
      findsOneWidget,
    );
    expect(find.text('Network error. Please try again.'), findsNothing);
  });
}
