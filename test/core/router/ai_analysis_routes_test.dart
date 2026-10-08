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
import 'package:mobile/features/ai_analysis/domain/entities/ai_topic_insight.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_details.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/attempt_summary.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/entities/topic_performance.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  roles: ['USER'],
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

const _overview = PerformanceOverview(
  totalAttempts: 1,
  questionsPracticed: 20,
  totalAnswered: 20,
  totalCorrect: 18,
  overallScorePercent: 90.0,
  totalTime: Duration(seconds: 1200),
  averageTimePerQuestion: Duration(seconds: 60),
);

const _topic = TopicPerformance(
  topicId: 'topic-budgeting',
  topicName: 'Budgeting',
  questionsAttempted: 20,
  answered: 20,
  correct: 18,
  wrong: 2,
  averageTimePerQuestion: Duration(seconds: 60),
);

final _attempt = AttemptSummary(
  attemptId: 'perf-attempt-1',
  type: AttemptType.studySession,
  completedAt: DateTime(2026, 9, 16, 9),
  contentLabel: 'Budgeting',
  totalQuestions: 20,
  answered: 20,
  correct: 18,
  scorePercent: 90.0,
  duration: const Duration(seconds: 1200),
);

final _attemptDetails = AttemptDetails(
  summary: _attempt,
  unanswered: 0,
  wrong: 2,
  averageTimePerQuestion: const Duration(seconds: 60),
  topics: const [_topic],
);

final _overallAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.overall,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 1,
  ),
  overallSummary: 'Your recent practice shows strong performance overall.',
  topicInsights: const [
    AiTopicInsight(
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      accuracyPercent: 90,
      answered: 20,
      correct: 18,
      interpretation: 'Solid grasp of this topic.',
      recommendedAction: 'Keep reinforcing it.',
    ),
  ],
);

final _topicAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.topic,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    topicId: 'topic-budgeting',
  ),
  overallSummary: 'Your performance in Budgeting is strong.',
  topicInsights: const [
    AiTopicInsight(
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      accuracyPercent: 90,
      answered: 20,
      correct: 18,
      interpretation: 'Solid grasp of this topic.',
      recommendedAction: 'Keep reinforcing it.',
    ),
  ],
);

final _attemptAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.attempt,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    attemptId: 'perf-attempt-1',
  ),
  overallSummary: 'This Study Session attempt finished at 90% accuracy.',
);

Widget _app({
  required AuthRepository authRepository,
  required PerformanceRepository performanceRepository,
  required AiAnalysisRepository aiAnalysisRepository,
}) {
  final notificationsRepository = MockNotificationsRepository();
  when(() => notificationsRepository.getUnreadCount())
      .thenAnswer((_) async => const Result.success(0));
  when(() => notificationsRepository.getStudyReminders())
      .thenAnswer((_) async => const Result.success([]));

  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      performanceRepositoryProvider.overrideWithValue(performanceRepository),
      aiAnalysisRepositoryProvider.overrideWithValue(aiAnalysisRepository),
      notificationsRepositoryProvider.overrideWithValue(
        notificationsRepository,
      ),
    ],
    child: const App(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets('an unauthenticated user cannot reach /performance/ai-analysis — '
      'redirected to login instead', (tester) async {
    final authRepository = MockAuthRepository();
    when(() => authRepository.restoreSession()).thenAnswer((_) async => null);
    final performanceRepository = MockPerformanceRepository();
    final aiAnalysisRepository = MockAiAnalysisRepository();

    await tester.pumpWidget(
      _app(
        authRepository: authRepository,
        performanceRepository: performanceRepository,
        aiAnalysisRepository: aiAnalysisRepository,
      ),
    );
    await tester.pumpAndSettle();

    verifyNever(
      () => aiAnalysisRepository.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    );
    expect(find.text('Welcome back'), findsOneWidget); // LoginScreen
  });

  testWidgets(
    'an authenticated user can navigate Performance -> AI Analysis -> Topic '
    'AI Insight, and Attempt Details -> Attempt AI Insight',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession())
          .thenAnswer((_) async => _session);

      final performanceRepository = MockPerformanceRepository();
      when(
        () => performanceRepository.getOverview(filter: any(named: 'filter')),
      ).thenAnswer((_) async => const Result.success(_overview));
      when(
        () => performanceRepository.getTopicPerformance(
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => const Result.success([_topic]));
      when(
        () => performanceRepository.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          AttemptHistoryPage(items: [_attempt], hasMore: false),
        ),
      );
      when(() => performanceRepository.getAttemptDetails('perf-attempt-1'))
          .thenAnswer((_) async => Result.success(_attemptDetails));

      final aiAnalysisRepository = MockAiAnalysisRepository();
      when(
        () => aiAnalysisRepository.getOverallAnalysis(
          filter: any(named: 'filter'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_overallAnalysis));
      when(
        () => aiAnalysisRepository.getTopicAnalysis(
          topicId: 'topic-budgeting',
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_topicAnalysis));
      when(
        () => aiAnalysisRepository.getAttemptAnalysis(
          attemptId: 'perf-attempt-1',
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_attemptAnalysis));

      await tester.pumpWidget(
        _app(
          authRepository: authRepository,
          performanceRepository: performanceRepository,
          aiAnalysisRepository: aiAnalysisRepository,
        ),
      );
      await tester.pumpAndSettle();

      // Home -> Performance Overview, via the dashboard's Performance
      // Snapshot card (see performance_routes_test.dart's own note on why
      // this isn't `find.text('Performance')` anymore).
      await tester.tap(find.text('See Performance'));
      await tester.pumpAndSettle();
      expect(find.text('Performance'), findsWidgets);

      // Overview -> AI Analysis (the entry panel's eyebrow title renders
      // upper-case since the MADEEN redesign).
      await tester.tap(find.text('AI ANALYSIS'));
      await tester.pumpAndSettle();
      expect(find.text('AI Analysis'), findsWidgets); // AppBar + entry card
      expect(
        find.text('Your recent practice shows strong performance overall.'),
        findsOneWidget,
      );

      // AI Analysis -> Topic AI Insight (tap the topic insight card).
      await tester.tap(find.text('Budgeting'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your performance in Budgeting is strong.'),
        findsOneWidget,
      );
      verify(
        () => aiAnalysisRepository.getTopicAnalysis(
          topicId: 'topic-budgeting',
          languageCode: any(named: 'languageCode'),
        ),
      ).called(1);

      // Back to Performance Overview -> Attempt History -> Attempt Details.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budgeting'));
      await tester.pumpAndSettle();
      expect(find.text('Attempt Details'), findsOneWidget);

      // Attempt Details -> Attempt AI Insight.
      await tester.tap(find.text('Analyze with AI'));
      await tester.pumpAndSettle();
      expect(
        find.text('This Study Session attempt finished at 90% accuracy.'),
        findsOneWidget,
      );
      verify(
        () => aiAnalysisRepository.getAttemptAnalysis(
          attemptId: 'perf-attempt-1',
          languageCode: any(named: 'languageCode'),
        ),
      ).called(1);
    },
  );
}
