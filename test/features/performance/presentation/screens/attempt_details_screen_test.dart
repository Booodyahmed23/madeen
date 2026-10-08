import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_details.dart';
import 'package:mobile/features/performance/domain/entities/attempt_summary.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/topic_performance.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/features/performance/presentation/screens/attempt_details_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

final _studySessionDetails = AttemptDetails(
  summary: AttemptSummary(
    attemptId: 'perf-attempt-1',
    type: AttemptType.studySession,
    completedAt: DateTime(2026, 9, 16, 9),
    contentLabel: 'Budgeting',
    totalQuestions: 20,
    answered: 20,
    correct: 18,
    scorePercent: 90.0,
    duration: const Duration(seconds: 1200),
  ),
  unanswered: 0,
  wrong: 2,
  averageTimePerQuestion: const Duration(seconds: 60),
  topics: const [
    TopicPerformance(
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      questionsAttempted: 20,
      answered: 20,
      correct: 18,
      wrong: 2,
      averageTimePerQuestion: Duration(seconds: 60),
    ),
  ],
);

final _examDetails = AttemptDetails(
  summary: AttemptSummary(
    attemptId: 'perf-attempt-2',
    type: AttemptType.examSimulation,
    completedAt: DateTime(2026, 9, 15, 14),
    contentLabel: 'CMA Part 1',
    totalQuestions: 80,
    answered: 74,
    correct: 58,
    scorePercent: 72.5,
    duration: const Duration(seconds: 12000),
  ),
  unanswered: 6,
  wrong: 16,
  averageTimePerQuestion: const Duration(seconds: 150),
  // Exam attempts carry no topic breakdown.
  topics: const [],
);

Widget _wrap(PerformanceRepository repository, String attemptId) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [performanceRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AttemptDetailsScreen(attemptId: attemptId),
    ),
  );
}

void main() {
  testWidgets('shows every field for a Study Session attempt, plus its topic '
      'breakdown', (tester) async {
    // Tall viewport so the topic breakdown section below the fold is
    // actually built — same reasoning as the Overview screen's own test.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MockPerformanceRepository();
    when(() => repository.getAttemptDetails('perf-attempt-1'))
        .thenAnswer((_) async => Result.success(_studySessionDetails));

    await tester.pumpWidget(_wrap(repository, 'perf-attempt-1'));
    await tester.pumpAndSettle();

    expect(find.text('Budgeting'), findsWidgets); // header + topic row
    // scorePercent and accuracyPercent are both 90% here (answered == total).
    expect(find.text('90%'), findsWidgets);
    expect(find.text('20'), findsWidgets); // total questions + answered
    expect(find.text('0'), findsOneWidget); // unanswered
    expect(find.text('2'), findsOneWidget); // wrong
    expect(
      find.widgetWithText(OutlinedButton, 'Review answers'),
      findsOneWidget,
    );
  });

  testWidgets('shows "No topic breakdown" for an Exam Simulation attempt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MockPerformanceRepository();
    when(() => repository.getAttemptDetails('perf-attempt-2'))
        .thenAnswer((_) async => Result.success(_examDetails));

    await tester.pumpWidget(_wrap(repository, 'perf-attempt-2'));
    await tester.pumpAndSettle();

    expect(find.text('CMA Part 1'), findsOneWidget);
    expect(
      find.text('No topic breakdown is available for this attempt.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a loading indicator, then an error message on failure', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    final completer = Completer<Result<AttemptDetails>>();
    when(() => repository.getAttemptDetails('missing'))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repository, 'missing'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const Result.failure(UnknownFailure()));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });
}
