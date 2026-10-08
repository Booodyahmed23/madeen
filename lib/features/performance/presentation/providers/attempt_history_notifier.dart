import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/performance_repository_impl.dart';
import '../../domain/repositories/performance_repository.dart';
import 'attempt_history_state.dart';
import 'performance_filter_provider.dart';

/// Owns Attempt History's paginated fetch — screens only read
/// [AttemptHistoryState] and call [load]/[loadMore]/[retry], never the
/// repository directly (same rule as StudySessionNotifier/ExamNotifier).
class AttemptHistoryNotifier extends Notifier<AttemptHistoryState> {
  static const _pageSize = 20;

  // Not `late final`: unlike StudySessionNotifier/ExamNotifier (whose
  // build() runs exactly once), this notifier's build() re-runs every time
  // the watched `performanceFilterProvider` changes — see build() below.
  late PerformanceRepository _repository;

  @override
  AttemptHistoryState build() {
    _repository = ref.watch(performanceRepositoryProvider);
    // Watching (not just reading) the shared attemptType filter means
    // Riverpod rebuilds this whole notifier — re-running `build()` from
    // scratch — whenever it changes, so a stale accumulated list from a
    // different filter can never linger.
    ref.watch(performanceFilterProvider);
    // Deferred to a microtask rather than called directly: `load()`'s first
    // line writes `state`, and `state` isn't safe to write to until this
    // `build()` call has actually returned — same reasoning as
    // ThemeModeNotifier.build()'s `_restore()` call, just made explicit
    // here since `load()` (unlike `_restore()`) writes state before its
    // first `await`.
    Future.microtask(load);
    return const AttemptHistoryInitial();
  }

  Future<void> load() async {
    state = const AttemptHistoryLoading();
    final filter = ref.read(performanceFilterProvider);
    final result = await _repository.getAttempts(
      filter: filter,
      limit: _pageSize,
      offset: 0,
    );
    result.when(
      success: (page) {
        state = AttemptHistoryReady(items: page.items, hasMore: page.hasMore);
      },
      failure: (failure) => state = AttemptHistoryError(failure),
    );
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! AttemptHistoryReady ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    state = current.copyWith(isLoadingMore: true);

    final filter = ref.read(performanceFilterProvider);
    final result = await _repository.getAttempts(
      filter: filter,
      limit: _pageSize,
      offset: current.items.length,
    );
    result.when(
      success: (page) {
        state = AttemptHistoryReady(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
        );
      },
      // A failed "load more" keeps what's already on screen rather than
      // replacing it with a full error state — the student can simply try
      // "load more" again.
      failure: (_) => state = current.copyWith(isLoadingMore: false),
    );
  }

  Future<void> retry() => load();
}

final attemptHistoryNotifierProvider =
    NotifierProvider<AttemptHistoryNotifier, AttemptHistoryState>(
      AttemptHistoryNotifier.new,
    );
