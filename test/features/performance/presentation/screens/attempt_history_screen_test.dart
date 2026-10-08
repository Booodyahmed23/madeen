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
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/features/performance/presentation/screens/attempt_history_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

AttemptSummary _attempt(
  String id, {
  AttemptType type = AttemptType.studySession,
}) => AttemptSummary(
  attemptId: id,
  type: type,
  completedAt: DateTime(2026, 9, 16),
  contentLabel: 'Budgeting',
  totalQuestions: 20,
  answered: 20,
  correct: 18,
  scorePercent: 90.0,
  duration: const Duration(seconds: 1200),
);

Widget _wrap(PerformanceRepository repository) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [performanceRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AttemptHistoryScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets('shows every attempt once loaded', (tester) async {
    final repository = MockPerformanceRepository();
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => Result.success(
        AttemptHistoryPage(
          items: [_attempt('a1'), _attempt('a2')],
          hasMore: false,
        ),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Budgeting'), findsNWidgets(2));
  });

  testWidgets('shows the empty state when there is no history yet', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
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

  testWidgets('shows a "Load more" button when hasMore is true, and it loads '
      'the next page', (tester) async {
    final repository = MockPerformanceRepository();
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: 0,
      ),
    ).thenAnswer(
      (_) async => Result.success(
        AttemptHistoryPage(items: [_attempt('a1')], hasMore: true),
      ),
    );
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: 1,
      ),
    ).thenAnswer(
      (_) async => Result.success(
        AttemptHistoryPage(items: [_attempt('a2')], hasMore: false),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Load more'), findsOneWidget);
    expect(find.text('Budgeting'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Budgeting'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Load more'), findsNothing);
  });

  testWidgets('shows a localized error message and a retry button on failure', (
    tester,
  ) async {
    final repository = MockPerformanceRepository();
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

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
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) return const Result.failure(NetworkFailure());
      return Result.success(
        AttemptHistoryPage(items: [_attempt('a1')], hasMore: false),
      );
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Budgeting'), findsOneWidget);
    expect(callCount, 2);
  });
}
