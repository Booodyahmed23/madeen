import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_notifier.dart';
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

class MockExamRepository extends Mock implements ExamRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  roles: ['USER'],
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

final _attempt = ExamAttempt(
  attemptId: 'attempt-1',
  durationSeconds: 1800,
  questions: [
    ExamQuestion(
      id: 'q1',
      text: 'Which cost behavior adjusts with volume under a flexible budget?',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [
        ExamAnswerChoice(id: 'q1-a', text: 'Variable cost', order: 0),
        ExamAnswerChoice(id: 'q1-b', text: 'Fixed cost', order: 1),
      ],
    ),
  ],
);

/// Builds the full [App], wiring every provider Home now reads (Performance,
/// AI Analysis, Notifications) plus whichever of Auth/Exam this test's own
/// scenario cares about — same pattern every other router test in this
/// directory already uses.
Widget _app({
  required AuthRepository authRepository,
  ExamRepository? examRepository,
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
    if (examRepository != null)
      examRepositoryProvider.overrideWithValue(examRepository),
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
    registerFallbackValue(
      const ExamConfig(
        programId: 'x',
        programName: 'x',
        partId: 'x',
        partName: 'x',
        questionCount: 25,
        duration: Duration(minutes: 30),
      ),
    );
  });

  testWidgets(
    'an unauthenticated user cannot reach /ai-tutor — redirected to login',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);

      await tester.pumpWidget(_app(authRepository: authRepository));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget); // LoginScreen
    },
  );

  testWidgets(
    'an authenticated user can reach AI Tutor from Home and send a message',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession())
          .thenAnswer((_) async => _session);

      await tester.pumpWidget(_app(authRepository: authRepository));
      await tester.pumpAndSettle();

      expect(find.text('AI Tutor'), findsOneWidget); // Home's entry card
      await tester.tap(find.text('AI Tutor'));
      await tester.pumpAndSettle();

      expect(find.text('Ask me anything about your studies'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'What is variance analysis?',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('What is variance analysis?'), findsOneWidget);
      expect(find.textContaining('Variance analysis compares'), findsOneWidget);
    },
  );

  testWidgets(
    "while an exam is active, Home's AI Tutor card is shown disabled and "
    'navigating to /ai-tutor by any other means redirects back to the exam',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession())
          .thenAnswer((_) async => _session);

      final examRepository = MockExamRepository();
      when(() => examRepository.startExam(any()))
          .thenAnswer((_) async => Result.success(_attempt));

      await tester.pumpWidget(
        _app(authRepository: authRepository, examRepository: examRepository),
      );
      await tester.pumpAndSettle();

      // Drive examNotifierProvider to ExamActive directly, without going
      // through the Exam Setup screen's own UI — this test is about the
      // AI Tutor block, not the exam-start flow itself (already covered
      // by exam_simulation_routes_test.dart).
      final context = tester.element(find.byType(Scaffold).first);
      final container = ProviderScope.containerOf(context);
      await container
          .read(examNotifierProvider.notifier)
          .startExam(
            const ExamConfig(
              programId: 'program-cma',
              programName: 'CMA',
              partId: 'part-1',
              partName: 'Part 1',
              questionCount: 1,
              duration: Duration(minutes: 30),
            ),
          );
      await tester.pumpAndSettle();

      // Home's own entry card now shows the disabled treatment.
      expect(
        find.text('Unavailable during an exam simulation'),
        findsOneWidget,
      );

      // Any other attempt to reach /ai-tutor (not just tapping Home's own
      // disabled card) is caught by the router's redirect too.
      GoRouter.of(context).push(AppRoutes.aiTutor);
      await tester.pumpAndSettle();

      expect(find.text('Ask me anything about your studies'), findsNothing);
      expect(
        find.text(
          'Which cost behavior adjusts with volume under a flexible budget?',
        ),
        findsOneWidget,
      );
    },
  );
}
