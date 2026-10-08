import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/topic_performance.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/features/performance/presentation/screens/topic_performance_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

const _strong = TopicPerformance(
  topicId: 'topic-budgeting',
  topicName: 'Budgeting',
  questionsAttempted: 20,
  answered: 20,
  correct: 18,
  wrong: 2,
  averageTimePerQuestion: Duration(seconds: 60),
);

const _needsPractice = TopicPerformance(
  topicId: 'topic-variance-analysis',
  topicName: 'Variance Analysis',
  questionsAttempted: 20,
  answered: 20,
  correct: 11,
  wrong: 9,
  averageTimePerQuestion: Duration(seconds: 90),
);

Widget _wrap(PerformanceRepository repository) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [performanceRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TopicPerformanceScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets('shows every topic once loaded', (tester) async {
    final repository = MockPerformanceRepository();
    when(
      () => repository.getTopicPerformance(filter: any(named: 'filter')),
    ).thenAnswer((_) async => const Result.success([_strong, _needsPractice]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Budgeting'), findsOneWidget);
    expect(find.text('Variance Analysis'), findsOneWidget);
  });

  testWidgets('the Strong filter shows only strong topics', (tester) async {
    final repository = MockPerformanceRepository();
    when(
      () => repository.getTopicPerformance(filter: any(named: 'filter')),
    ).thenAnswer((_) async => const Result.success([_strong, _needsPractice]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Strong').first);
    await tester.pumpAndSettle();

    expect(find.text('Budgeting'), findsOneWidget);
    expect(find.text('Variance Analysis'), findsNothing);
  });

  testWidgets('the Needs Practice filter shows only needs-practice topics', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    when(
      () => repository.getTopicPerformance(filter: any(named: 'filter')),
    ).thenAnswer((_) async => const Result.success([_strong, _needsPractice]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Needs Practice').first);
    await tester.pumpAndSettle();

    expect(find.text('Variance Analysis'), findsOneWidget);
    expect(find.text('Budgeting'), findsNothing);
  });

  testWidgets('shows the empty state when there are no topics yet', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No topic performance yet — complete a study session to see it here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows an error message on failure', (tester) async {
    final repository = MockPerformanceRepository();
    when(() => repository.getTopicPerformance(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
  });
}
