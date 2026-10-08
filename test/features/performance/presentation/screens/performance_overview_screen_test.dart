import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/attempt_summary.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/entities/topic_performance.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/features/performance/presentation/screens/performance_overview_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

const _overview = PerformanceOverview(
  totalAttempts: 6,
  questionsPracticed: 205,
  totalAnswered: 197,
  totalCorrect: 151,
  overallScorePercent: 73.66,
  totalTime: Duration(seconds: 25000),
  averageTimePerQuestion: Duration(seconds: 121),
);

const _emptyOverview = PerformanceOverview(
  totalAttempts: 0,
  questionsPracticed: 0,
  totalAnswered: 0,
  totalCorrect: 0,
  overallScorePercent: 0,
  totalTime: Duration.zero,
  averageTimePerQuestion: Duration.zero,
);

const _topic = TopicPerformance(
  topicId: 't1',
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

Widget _wrap(
  PerformanceRepository repository, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [performanceRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PerformanceOverviewScreen(),
    ),
  );
}

void _stubHappyPath(MockPerformanceRepository repository) {
  when(() => repository.getOverview(filter: any(named: 'filter')))
      .thenAnswer((_) async => const Result.success(_overview));
  when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
      .thenAnswer((_) async => const Result.success([_topic]));
  when(
    () => repository.getAttempts(
      filter: any(named: 'filter'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer(
    (_) async =>
        Result.success(AttemptHistoryPage(items: [_attempt], hasMore: false)),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets('shows a loading indicator while the overview is fetched', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    final completer = Completer<Result<PerformanceOverview>>();
    when(() => repository.getOverview(filter: any(named: 'filter')))
        .thenAnswer((_) => completer.future);
    when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success([]));
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(const Result.success(_emptyOverview));
    await tester.pumpAndSettle();
  });

  testWidgets('shows the empty state when there are no attempts yet', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    when(() => repository.getOverview(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success(_emptyOverview));
    when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success([]));
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('No performance data yet.'), findsOneWidget);
  });

  testWidgets('shows overall accuracy/score and headline stats once loaded', (
    tester,
  ) async {
    // Tall viewport so the below-the-fold Topic Performance / Recent
    // Attempts sections are actually built (ListView virtualizes offscreen
    // children), matching the pattern exam_simulation_routes_test.dart
    // already uses for the same reason.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MockPerformanceRepository();
    _stubHappyPath(repository);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    // overallAccuracyPercent = 151/197*100 ≈ 76.65 -> rounds to 77%.
    expect(find.text('77%'), findsOneWidget);
    // overallScorePercent = 73.66 -> rounds to 74%.
    expect(find.text('74%'), findsOneWidget);
    expect(find.text('205'), findsOneWidget); // questions practiced
    expect(find.text('Budgeting'), findsWidgets); // topic + attempt preview
  });

  testWidgets('shows a localized error message and a retry button on failure', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    when(() => repository.getOverview(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));
    when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success([]));
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('retry re-fetches after a failure', (tester) async {
    final repository = MockPerformanceRepository();
    var callCount = 0;
    when(() => repository.getOverview(filter: any(named: 'filter')))
        .thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return const Result.failure(NetworkFailure());
          return const Result.success(_emptyOverview);
        });
    when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success([]));
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('No performance data yet.'), findsOneWidget);
    expect(callCount, 2);
  });

  testWidgets('renders in Arabic (RTL) without crashing', (tester) async {
    final repository = MockPerformanceRepository();
    _stubHappyPath(repository);

    await tester.pumpWidget(_wrap(repository, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الأداء'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
