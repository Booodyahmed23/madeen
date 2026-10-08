import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/course/data/repositories/course_repository_impl.dart';
import 'package:mobile/features/course/domain/entities/course.dart';
import 'package:mobile/features/course/domain/entities/course_enrollment.dart';
import 'package:mobile/features/course/domain/entities/course_section.dart';
import 'package:mobile/features/course/domain/entities/lesson.dart';
import 'package:mobile/features/course/domain/repositories/course_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

class MockCourseRepository extends Mock implements CourseRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  role: 'USER',
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

const _overview = PerformanceOverview(
  totalAttempts: 0,
  questionsPracticed: 0,
  totalAnswered: 0,
  totalCorrect: 0,
  overallScorePercent: 0,
  totalTime: Duration.zero,
  averageTimePerQuestion: Duration.zero,
);

final _insufficientAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.overall,
    status: AiAnalysisStatus.insufficientData,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 0,
  ),
  overallSummary: 'Complete a Study Session to unlock personalized insights.',
);

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
      ],
    ),
  ],
);

/// Builds the full [App], wiring every provider Home now reads plus the
/// Course repository — same pattern every other router test in this
/// directory already uses (see `ai_tutor_routes_test.dart`).
Widget _app({
  required AuthRepository authRepository,
  CourseRepository? courseRepository,
}) {
  final notificationsRepository = MockNotificationsRepository();
  when(() => notificationsRepository.getUnreadCount())
      .thenAnswer((_) async => const Result.success(0));
  when(() => notificationsRepository.getStudyReminders())
      .thenAnswer((_) async => const Result.success([]));

  final performanceRepository = MockPerformanceRepository();
  when(() => performanceRepository.getOverview(filter: any(named: 'filter')))
      .thenAnswer((_) async => const Result.success(_overview));
  when(
    () => performanceRepository.getAttempts(
      filter: any(named: 'filter'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
  );

  final aiAnalysisRepository = MockAiAnalysisRepository();
  when(
    () => aiAnalysisRepository.getOverallAnalysis(
      filter: any(named: 'filter'),
      languageCode: any(named: 'languageCode'),
    ),
  ).thenAnswer((_) async => Result.success(_insufficientAnalysis));

  final overrides = [
    authRepositoryProvider.overrideWithValue(authRepository),
    notificationsRepositoryProvider.overrideWithValue(notificationsRepository),
    performanceRepositoryProvider.overrideWithValue(performanceRepository),
    aiAnalysisRepositoryProvider.overrideWithValue(aiAnalysisRepository),
    if (courseRepository != null)
      courseRepositoryProvider.overrideWithValue(courseRepository),
  ];

  return ProviderScope(
    retry: appRetryPolicy,
    overrides: overrides,
    child: const App(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets(
    'an unauthenticated user cannot reach /courses — redirected to login',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);

      await tester.pumpWidget(_app(authRepository: authRepository));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget); // LoginScreen
    },
  );

  testWidgets(
    'an authenticated user can reach Courses from Home, open a course and a lesson',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession())
          .thenAnswer((_) async => _session);

      final courseRepository = MockCourseRepository();
      when(
        () => courseRepository.getCourses(
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success([_course]));
      when(() => courseRepository.getEnrollment(any())).thenAnswer(
        (_) async =>
            const Result.success(CourseEnrollment(courseId: 'course-1')),
      );
      when(
        () => courseRepository.setLastAccessedLesson(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
        ),
      ).thenAnswer(
        (_) async =>
            const Result.success(CourseEnrollment(courseId: 'course-1')),
      );

      await tester.pumpWidget(
        _app(
          authRepository: authRepository,
          courseRepository: courseRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Courses'), findsOneWidget); // Home's entry card
      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();

      expect(find.text('CMA Part 1 Video Course'), findsWidgets);
      await tester.tap(find.text('CMA Part 1 Video Course').first);
      await tester.pumpAndSettle();

      expect(find.text('Introduction to Budgeting'), findsOneWidget);
      await tester.tap(find.text('Introduction to Budgeting'));
      await tester.pumpAndSettle();

      expect(find.text('Why budgets exist.'), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'Mark as completed'),
        findsOneWidget,
      );
    },
  );
}
