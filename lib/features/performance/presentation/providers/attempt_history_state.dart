import '../../../../core/error/app_failure.dart';
import '../../domain/entities/attempt_summary.dart';

/// Attempt History's own state machine — kept separate from the simpler
/// `AsyncValue`-based providers in performance_providers.dart because
/// pagination needs to accumulate items across multiple fetches
/// (`loadMore`), which a bare `FutureProvider` can't express cleanly. Covers
/// this phase's minimum requirement (Initial/Loading/Ready/Error) plus the
/// two extra fields `loadMore` genuinely needs — nothing more.
sealed class AttemptHistoryState {
  const AttemptHistoryState();
}

class AttemptHistoryInitial extends AttemptHistoryState {
  const AttemptHistoryInitial();
}

/// First page loading, or a full reload after the filter changed.
class AttemptHistoryLoading extends AttemptHistoryState {
  const AttemptHistoryLoading();
}

class AttemptHistoryReady extends AttemptHistoryState {
  const AttemptHistoryReady({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<AttemptSummary> items;
  final bool hasMore;

  /// True only while a `loadMore` page fetch is in flight — the existing
  /// [items] stay on screen underneath, never cleared for a "load more"
  /// spinner.
  final bool isLoadingMore;

  AttemptHistoryReady copyWith({
    List<AttemptSummary>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return AttemptHistoryReady(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class AttemptHistoryError extends AttemptHistoryState {
  const AttemptHistoryError(this.failure);

  final AppFailure failure;
}
