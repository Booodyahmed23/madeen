import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/practice_attempt_recorder.dart';
import 'package:mobile/app/widgets/performance_snapshot_card.dart';
import 'package:mobile/app/widgets/recent_activity_section.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/theme_mode_provider.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../features/performance/local_attempt_test_data.dart';
import '../features/subscription/access_overrides.dart';
import '../features/study_session/study_session_fixtures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

class MockExamRepository extends Mock implements ExamRepository {}

/// Phase 13 end to end: the real App, router, screens, recorder, local
/// attempt store, Performance mock and AI mock — only auth and the two
/// practice repositories are mocked (so the flows are instant and their
/// results deterministic: the same 30% study session and 8% exam verified
/// live on the simulator).
void main() {
  late MockAuthRepository auth;
  late MockStudySessionRepository study;
  late MockExamRepository exam;

  setUpAll(() {
    registerFallbackValue(varianceConfig);
    registerFallbackValue(cmaPart2Config);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(<String>{});
  });

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer(
      (_) async => const AuthSession(
        user: AuthUser(
          id: 'user-a',
          email: 'a@example.com',
          firstName: 'Ada',
          lastName: 'User',
          role: 'USER',
        ),
        accessToken: 'token',
      ),
    );

    study = MockStudySessionRepository();
    when(() => study.startSession(any()))
        .thenAnswer((_) async => Result.success(varianceSession()));
    when(
      () => study.answerQuestion(
        sessionId: any(named: 'sessionId'),
        questionId: any(named: 'questionId'),
        choiceId: any(named: 'choiceId'),
        timeSpentSeconds: any(named: 'timeSpentSeconds'),
      ),
    ).thenAnswer(
      (_) async => Result.success(varianceSession(answeredCount: 1)),
    );
    when(() => study.completeSession(any())).thenAnswer(
      (_) async => Result.success(varianceSession(status: 'COMPLETED')),
    );

    exam = MockExamRepository();
    when(() => exam.startExam(any())).thenAnswer(
      (_) async => const Result.success(
        ExamAttempt(
          attemptId: 'mock-attempt-0',
          questions: [
            ExamQuestion(
              id: 'eq1',
              text: 'Exam question',
              type: ExamQuestionType.multipleChoiceSingle,
              choices: [ExamAnswerChoice(id: 'ec1', text: 'Exam answer')],
            ),
          ],
          durationSeconds: 1800,
        ),
      ),
    );
    when(
      () => exam.submitExam(
        attemptId: any(named: 'attemptId'),
        answers: any(named: 'answers'),
        flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
        timeTaken: any(named: 'timeTaken'),
      ),
    ).thenAnswer((_) async => const Result.success(cmaPart2Result));
    when(() => exam.getReview(any()))
        .thenAnswer((_) async => const Result.success([]));
  });

  /// One "app launch" on a fresh container (SharedPreferences persists
  /// across launches within a test, like the device's storage).
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    Locale? locale,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ...accessOverrides(),
        authRepositoryProvider.overrideWithValue(auth),
        studySessionRepositoryProvider.overrideWithValue(study),
        examRepositoryProvider.overrideWithValue(exam),
        practiceClockProvider.overrideWithValue(
          () => DateTime(2026, 10, 4, 19, 6),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (locale != null) {
      await container.read(localeProvider.notifier).setLocale(locale);
    }
    await container.read(themeModeProvider.notifier).setThemeMode(themeMode);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder inSnapshot(String text) => find.descendant(
    of: find.byType(PerformanceSnapshotCard),
    matching: find.text(text),
  );

  Finder inRecentActivity(String text) => find.descendant(
    of: find.byType(RecentActivitySection),
    matching: find.text(text),
  );

  Future<void> completeStudySession(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container
        .read(appRouterProvider)
        .go(
          AppRoutes.curriculumTopicDetail('topic-variance-analysis'),
          extra: 'Variance Analysis',
        );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A difference'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Review & submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit session'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('30%'), findsOneWidget, reason: 'on Results');
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
  }

  Future<void> completeExam(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.read(appRouterProvider).go(AppRoutes.examSetup);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Program>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CMA').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Part>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exam answer'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('8%'), findsOneWidget, reason: 'on Results');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'complete a Study Session -> Home updates -> Performance shows it',
    (tester) async {
      final container = await launch(tester);
      expect(inSnapshot('6'), findsOneWidget, reason: 'fixtures only');

      await completeStudySession(tester, container);

      // Done returns Home, which has already updated — no refresh.
      expect(find.text('Pass CMA & FMAA with confidence'), findsOneWidget);
      expect(inSnapshot('7'), findsOneWidget);
      expect(inSnapshot('215'), findsOneWidget);
      expect(inSnapshot('75%'), findsOneWidget);
      expect(inRecentActivity('Variance Analysis'), findsOneWidget);
      expect(find.textContaining('7 attempts'), findsOneWidget, reason: 'AI');

      await tester.tap(find.text('See Performance'));
      await tester.pumpAndSettle();
      expect(find.text('215'), findsOneWidget);
      // Fixture 11/20 + local 3/9, aggregated into one row.
      expect(find.text('48%'), findsOneWidget);
    },
  );

  testWidgets('complete an Exam -> Home updates -> Performance shows it', (
    tester,
  ) async {
    final container = await launch(tester);

    await completeExam(tester, container);

    expect(inSnapshot('7'), findsOneWidget);
    expect(inSnapshot('230'), findsOneWidget);
    expect(inRecentActivity('CMA Part 2'), findsOneWidget);

    await tester.tap(find.text('See Performance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exam Simulation').first);
    await tester.pumpAndSettle();
    expect(find.text('CMA Part 2'), findsWidgets);
  });

  testWidgets('both attempts survive an app relaunch (new container)', (
    tester,
  ) async {
    final first = await launch(tester);
    await completeStudySession(tester, first);
    await completeExam(tester, first);
    expect(inSnapshot('8'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    first.dispose();
    await launch(tester);

    expect(inSnapshot('8'), findsOneWidget);
    expect(inSnapshot('240'), findsOneWidget);
    expect(inSnapshot('73%'), findsOneWidget);
    expect(inSnapshot('65%'), findsOneWidget);
  });

  testWidgets('Arabic + dark: Home reflects a recorded attempt, RTL', (
    tester,
  ) async {
    final container = await launch(
      tester,
      locale: const Locale('ar'),
      themeMode: ThemeMode.dark,
    );
    container
        .read(appRouterProvider)
        .go(
          AppRoutes.curriculumTopicDetail('topic-variance-analysis'),
          extra: 'Variance Analysis',
        );
    await tester.pumpAndSettle();
    await completeStudySessionInAnyLanguage(tester, container);

    final context = tester.element(find.byType(PerformanceSnapshotCard));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(inSnapshot('7'), findsOneWidget);
    expect(inRecentActivity('Variance Analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// The same Study Session flow as `completeStudySession`, but located by
/// widget type instead of English labels, so it runs on the Arabic screens:
/// Start → answer → submit answer → Submission Review → Submit → confirm →
/// Results → Done (Home).
Future<void> completeStudySessionInAnyLanguage(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('A difference'));
  await tester.pump();
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go(AppRoutes.studySessionSubmissionReview);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}
