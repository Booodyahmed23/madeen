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
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/subscription/access_overrides.dart';
import '../../features/exam_simulation/exam_fixtures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

class MockExamRepository extends Mock implements ExamRepository {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

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

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  role: 'USER',
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ExamConfig(
        programId: 'x',
        programName: 'x',
        partId: 'x',
        partName: 'x',
        questionCount: 25,
        duration: Duration(minutes: 30),
        topicIds: ['topic-1'],
      ),
    );
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(<String>{});
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets('a student walks the whole flow: Home -> Exam Setup -> Active -> '
      'Submission Review -> Results -> Post-Exam Review', (tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final authRepository = MockAuthRepository();
    when(() => authRepository.restoreSession())
        .thenAnswer((_) async => _session);

    final curriculumRepository = MockCurriculumRepository();
    when(() => curriculumRepository.getPrograms()).thenAnswer(
      (_) async =>
          const Result.success([Program(id: 'program-cma', name: 'CMA')]),
    );
    when(() => curriculumRepository.getProgramTree('program-cma'))
        .thenAnswer((_) async => Result.success(examCurriculumTree()));

    final examRepository = FakeExamRepository(
      remainingSeconds: 60,
      submittedAfter: const Duration(seconds: 20),
      questions: const [
        FakeExamQuestion(
          id: 'q1',
          text: 'Which cost behavior adjusts with volume under a flexible budget?',
          choices: {'q1-a': 'Variable cost', 'q1-b': 'Fixed cost'},
          correctChoiceId: 'q1-a',
          explanation: 'Variable costs scale with volume; fixed costs do not.',
        ),
      ],
    );

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

    await tester.pumpWidget(
      ProviderScope(
        retry: appRetryPolicy,
        overrides: [
          ...accessOverrides(),
          authRepositoryProvider.overrideWithValue(authRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
          examRepositoryProvider.overrideWithValue(examRepository),
          notificationsRepositoryProvider.overrideWithValue(
            notificationsRepository,
          ),
          performanceRepositoryProvider.overrideWithValue(
            performanceRepository,
          ),
          aiAnalysisRepositoryProvider.overrideWithValue(aiAnalysisRepository),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    // Home shows both Curriculum and Exam Simulation entry points.
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('Exam Simulation'), findsOneWidget);

    // Home -> Exam Setup
    await tester.tap(find.text('Exam Simulation'));
    await tester.pumpAndSettle();
    expect(find.text('Exam Simulation Setup'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<Program>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CMA').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Part>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start exam'));
    await tester.pumpAndSettle();

    // Setup -> Active exam. No topic label, countdown visible.
    expect(
      find.text(
        'Which cost behavior adjusts with volume under a flexible budget?',
      ),
      findsOneWidget,
    );
    expect(find.text('CMA'), findsNothing);
    expect(find.text('Part 1'), findsNothing);
    expect(find.text('01:00'), findsOneWidget);
    expect(examRepository.startedWith, hasLength(1));

    await tester.tap(find.text('Variable cost'));
    await tester.pump();
    // No feedback of any kind during the exam.
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Incorrect'), findsNothing);

    // Active -> Submission Review (the last question's bottom-bar action)
    await tester.tap(find.widgetWithText(FilledButton, 'Review'));
    await tester.pumpAndSettle();
    expect(find.text('Answered: 1'), findsOneWidget);
    expect(find.text('Unanswered: 0'), findsOneWidget);

    // Submission Review -> Results
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);

    // Results -> Post-Exam Review
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Review answers'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Review answers'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '1. Which cost behavior adjusts with volume under a flexible budget?',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Variable costs scale with volume; fixed costs do not.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'an unauthenticated user cannot reach the exam-simulation route directly',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);
      final examRepository = MockExamRepository();

      await tester.pumpWidget(
        ProviderScope(
          retry: appRetryPolicy,
          overrides: [
            ...accessOverrides(),
            authRepositoryProvider.overrideWithValue(authRepository),
            examRepositoryProvider.overrideWithValue(examRepository),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(() => examRepository.startExam(any()));
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
}
