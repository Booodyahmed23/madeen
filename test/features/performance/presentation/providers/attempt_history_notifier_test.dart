import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/attempt_summary.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/features/performance/presentation/providers/attempt_history_notifier.dart';
import 'package:mobile/features/performance/presentation/providers/attempt_history_state.dart';
import 'package:mobile/features/performance/presentation/providers/performance_filter_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

AttemptSummary _attempt(String id) => AttemptSummary(
  attemptId: id,
  type: AttemptType.studySession,
  completedAt: DateTime(2026, 9, 16),
  contentLabel: 'Budgeting',
  totalQuestions: 20,
  answered: 20,
  correct: 18,
  scorePercent: 90.0,
  duration: const Duration(seconds: 1200),
);

/// Every write to `state` in AttemptHistoryNotifier happens in a
/// `Future.microtask` (build) or after an `await` (load/loadMore) —
/// draining the microtask queue once is enough to observe the resulting
/// state without needing a real Timer/Future.delayed.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  late MockPerformanceRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockPerformanceRepository();
    container = ProviderContainer(
      overrides: [performanceRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test(
    'starts Initial, then Loading, then Ready after a successful fetch',
    () async {
      final completer = Completer<Result<AttemptHistoryPage>>();
      when(
        () => repository.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      // Triggers build(), which returns Initial synchronously and schedules
      // load() as a microtask.
      expect(
        container.read(attemptHistoryNotifierProvider),
        isA<AttemptHistoryInitial>(),
      );

      await _settle();
      expect(
        container.read(attemptHistoryNotifierProvider),
        isA<AttemptHistoryLoading>(),
      );

      completer.complete(
        Result.success(
          AttemptHistoryPage(
            items: [_attempt('a1'), _attempt('a2')],
            hasMore: true,
          ),
        ),
      );
      await _settle();

      final state = container.read(attemptHistoryNotifierProvider);
      expect(state, isA<AttemptHistoryReady>());
      expect((state as AttemptHistoryReady).items, hasLength(2));
      expect(state.hasMore, isTrue);
    },
  );

  test('a failed fetch surfaces AttemptHistoryError', () async {
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

    container.read(attemptHistoryNotifierProvider); // trigger build()
    await _settle();

    final state = container.read(attemptHistoryNotifierProvider);
    expect(state, isA<AttemptHistoryError>());
    expect((state as AttemptHistoryError).failure, isA<NetworkFailure>());
  });

  test('retry re-fetches after a failure', () async {
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

    container.read(attemptHistoryNotifierProvider); // trigger build()
    await _settle();
    expect(
      container.read(attemptHistoryNotifierProvider),
      isA<AttemptHistoryError>(),
    );

    await container.read(attemptHistoryNotifierProvider.notifier).retry();

    final state = container.read(attemptHistoryNotifierProvider);
    expect(state, isA<AttemptHistoryReady>());
    expect(callCount, 2);
  });

  test('loadMore appends items and keeps existing ones on screen', () async {
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

    container.read(attemptHistoryNotifierProvider); // trigger build()
    await _settle();
    var state =
        container.read(attemptHistoryNotifierProvider) as AttemptHistoryReady;
    expect(state.items, hasLength(1));
    expect(state.hasMore, isTrue);

    await container.read(attemptHistoryNotifierProvider.notifier).loadMore();

    state =
        container.read(attemptHistoryNotifierProvider) as AttemptHistoryReady;
    expect(state.items.map((a) => a.attemptId), ['a1', 'a2']);
    expect(state.hasMore, isFalse);
  });

  test('loadMore does nothing when hasMore is false', () async {
    when(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => Result.success(
        AttemptHistoryPage(items: [_attempt('a1')], hasMore: false),
      ),
    );

    container.read(attemptHistoryNotifierProvider); // trigger build()
    await _settle();
    await container.read(attemptHistoryNotifierProvider.notifier).loadMore();

    verify(
      () => repository.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  test(
    'load() reads and forwards the current shared attemptType filter',
    () async {
      when(
        () => repository.getAttempts(
          filter: const PerformanceFilter(
            attemptType: AttemptTypeFilter.examSimulation,
          ),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          AttemptHistoryPage(items: [_attempt('a1')], hasMore: false),
        ),
      );

      // Set the filter *before* this notifier is first built, so its initial
      // `load()` call picks it up — proves the same shared
      // `performanceFilterProvider` selection Overview/Topic Performance use
      // is exactly what Attempt History fetches with. Live reactivity to a
      // filter change *after* the screen is already mounted is covered by
      // AttemptHistoryScreen's widget test instead, since driving Riverpod's
      // own rebuild scheduler correctly needs a real Flutter binding pumping
      // frames, which a bare `ProviderContainer` unit test doesn't have.
      container
          .read(performanceFilterProvider.notifier)
          .setAttemptType(AttemptTypeFilter.examSimulation);
      container.read(attemptHistoryNotifierProvider);
      await _settle();

      verify(
        () => repository.getAttempts(
          filter: const PerformanceFilter(
            attemptType: AttemptTypeFilter.examSimulation,
          ),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(1);
    },
  );
}
