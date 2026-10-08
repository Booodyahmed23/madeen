import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/entities/sub_unit.dart';
import 'package:mobile/features/curriculum/domain/entities/topic.dart';
import 'package:mobile/features/curriculum/domain/entities/unit.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/curriculum/curriculum_test_tree.dart';
import '../../features/subscription/access_overrides.dart';

import 'package:mobile/core/network/paginated.dart';

import '../../features/study_session/study_session_fixtures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

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

const _question = FakeQuestion(
  id: 'q1',
  text: 'What adjusts under a flexible budget?',
  choices: {'q1-a': 'Variable costs', 'q1-b': 'Nothing'},
  correctChoiceId: 'q1-a',
  explanation: 'Flexible budgets adjust variable costs to volume.',
  timeSpentSeconds: 0,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const SessionConfig(
        topicId: 'x',
        topicName: 'x',
        questionCount: 10,
        feedbackMode: FeedbackMode.immediate,
      ),
    );
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets(
    'a student walks the whole flow: Curriculum -> Topic -> Setup -> Active -> '
    'Submission Review -> Results -> Review',
    (tester) async {
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
      when(() => curriculumRepository.getProgramTree('program-cma')).thenAnswer(
        (_) async => Result.success(
          testCurriculumTree(
            program: const Program(id: 'program-cma', name: 'CMA'),
            parts: const [
              Part(id: 'part-1', programId: 'program-cma', name: 'Part 1'),
            ],
            units: const [
              Unit(id: 'unit-fp', partId: 'part-1', name: 'Financial Planning'),
            ],
            subUnits: const [
              SubUnit(
                id: 'subunit-budgeting',
                unitId: 'unit-fp',
                name: 'Budgeting',
              ),
            ],
            topics: const [
              Topic(
                id: 'topic-flexible-budget',
                subUnitId: 'subunit-budgeting',
                name: 'Flexible Budget',
              ),
            ],
          ),
        ),
      );

      final studySessionRepository = MockStudySessionRepository();
      final answered = _question.answer('q1-a', addSeconds: 12);
      when(() => studySessionRepository.startSession(any())).thenAnswer(
        (_) async => Result.success(fakeSession(questions: const [_question])),
      );
      when(
        () => studySessionRepository.answerQuestion(
          sessionId: any(named: 'sessionId'),
          questionId: any(named: 'questionId'),
          choiceId: any(named: 'choiceId'),
          timeSpentSeconds: any(named: 'timeSpentSeconds'),
        ),
      ).thenAnswer(
        (_) async => Result.success(fakeSession(questions: [answered])),
      );
      when(() => studySessionRepository.completeSession(any())).thenAnswer(
        (_) async => Result.success(
          fakeSession(status: 'COMPLETED', questions: [answered]),
        ),
      );
      when(
        () => studySessionRepository.listSessions(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          Paginated(items: [], page: 1, limit: 20, total: 0, totalPages: 0),
        ),
      );
      final notificationsRepository = MockNotificationsRepository();
      when(() => notificationsRepository.getUnreadCount())
          .thenAnswer((_) async => const Result.success(0));
      when(() => notificationsRepository.getStudyReminders())
          .thenAnswer((_) async => const Result.success([]));
      final performanceRepository = MockPerformanceRepository();
      when(
        () => performanceRepository.getOverview(filter: any(named: 'filter')),
      ).thenAnswer((_) async => const Result.success(_overview));
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
            curriculumRepositoryProvider.overrideWithValue(
              curriculumRepository,
            ),
            studySessionRepositoryProvider.overrideWithValue(
              studySessionRepository,
            ),
            notificationsRepositoryProvider.overrideWithValue(
              notificationsRepository,
            ),
            performanceRepositoryProvider.overrideWithValue(
              performanceRepository,
            ),
            aiAnalysisRepositoryProvider.overrideWithValue(
              aiAnalysisRepository,
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      // Home -> Curriculum -> Programs -> Parts -> Units -> SubUnits -> Topics
      await tester.tap(find.text('Curriculum'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CMA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Financial Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budgeting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flexible Budget'));
      await tester.pumpAndSettle();

      // Topic -> Study Session Setup
      expect(find.text('Study Session Setup'), findsOneWidget);
      expect(find.text('Flexible Budget'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
      await tester.pumpAndSettle();

      // Setup -> Active session
      expect(
        find.text('What adjusts under a flexible budget?'),
        findsOneWidget,
      );
      verify(() => studySessionRepository.startSession(any())).called(1);

      await tester.tap(find.text('Variable costs'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit answer'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);

      // Active -> Submission Review
      await tester.tap(find.byTooltip('Review & submit'));
      await tester.pumpAndSettle();
      expect(find.text('Answered: 1'), findsOneWidget);

      // Submission Review -> Results
      await tester.tap(find.widgetWithText(FilledButton, 'Submit session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);

      // Results -> Review
      await tester.tap(find.widgetWithText(OutlinedButton, 'Review answers'));
      await tester.pumpAndSettle();
      expect(
        find.text('1. What adjusts under a flexible budget?'),
        findsOneWidget,
      );
      expect(
        find.text('Flexible budgets adjust variable costs to volume.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an unauthenticated user cannot reach a study-session route directly',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);
      final studySessionRepository = MockStudySessionRepository();

      await tester.pumpWidget(
        ProviderScope(
          retry: appRetryPolicy,
          overrides: [
            ...accessOverrides(),
            authRepositoryProvider.overrideWithValue(authRepository),
            studySessionRepositoryProvider.overrideWithValue(
              studySessionRepository,
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      // Redirected to login — the study session flow is never reachable.
      verifyNever(() => studySessionRepository.startSession(any()));
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
}
