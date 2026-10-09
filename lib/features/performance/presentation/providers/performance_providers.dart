import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../data/repositories/performance_repository_impl.dart';
import '../../domain/entities/attempt_details.dart';
import '../../domain/entities/performance_filter.dart';
import '../../domain/entities/performance_overview.dart';
import '../../domain/entities/attempt_summary.dart';
import '../../domain/entities/topic_performance.dart';
import '../../domain/entities/trend_day.dart';
import 'performance_filter_provider.dart';

/// Re-fetches whenever [performanceFilterProvider] changes (Riverpod's
/// `ref.watch` dependency tracking, same pattern as
/// curriculum_providers.dart) — Overview only reacts to `attemptType`, but
/// watching the whole filter is simpler than a second, narrower provider
/// and Riverpod already de-dupes identical rebuilds.
final performanceOverviewProvider =
    FutureProvider.autoDispose<PerformanceOverview>((ref) async {
      final filter = ref.watch(performanceFilterProvider);
      final result = await ref
          .watch(performanceRepositoryProvider)
          .getOverview(filter: filter);
      return _unwrap(result);
    });

/// Every topic the student has practiced (attemptType-scoped only — see
/// PerformanceRepository.getTopicPerformance). The Strong / Needs Practice
/// bucketing is applied on top of this by
/// [filteredTopicPerformanceProvider], not re-fetched per filter, since it's
/// a pure client-side view over already-fetched factual numbers.
final topicPerformanceProvider =
    FutureProvider.autoDispose<List<TopicPerformance>>((ref) async {
      final filter = ref.watch(performanceFilterProvider);
      final result = await ref
          .watch(performanceRepositoryProvider)
          .getTopicPerformance(filter: filter);
      return _unwrap(result);
    });

/// [topicPerformanceProvider] filtered by the current `topicFilter` (All /
/// Strong / Needs Practice) — kept as a `Provider`, not folded into the
/// fetch itself, because filtering by [TopicPerformance.isStrong] /
/// [TopicPerformance.needsPractice] never needs another round trip.
final filteredTopicPerformanceProvider =
    Provider.autoDispose<AsyncValue<List<TopicPerformance>>>((ref) {
      final topicsAsync = ref.watch(topicPerformanceProvider);
      final topicFilter = ref.watch(performanceFilterProvider).topicFilter;
      return topicsAsync.whenData((topics) {
        return switch (topicFilter) {
          TopicPerformanceFilter.all => topics,
          TopicPerformanceFilter.strong =>
            topics.where((t) => t.isStrong).toList(),
          TopicPerformanceFilter.needsPractice =>
            topics.where((t) => t.needsPractice).toList(),
        };
      });
    });

/// A short (3-item) preview of the most recent attempts for the Overview
/// screen — its own provider rather than reusing
/// [attemptHistoryNotifierProvider] because a preview never accumulates
/// pages or exposes "load more"; it's a single small fetch.
final recentAttemptsPreviewProvider =
    FutureProvider.autoDispose<List<AttemptSummary>>((ref) async {
      final filter = ref.watch(performanceFilterProvider);
      final result = await ref
          .watch(performanceRepositoryProvider)
          .getAttempts(filter: filter, limit: 3, offset: 0);
      return _unwrap(result).items;
    });

/// One attempt's full detail, cached per `attemptId` — mirrors
/// curriculum_providers.dart's per-parent-id caching (`FutureProvider.family`)
/// exactly; revisiting an attempt already fetched this session doesn't
/// re-hit the network.
final attemptDetailsProvider = FutureProvider.family
    .autoDispose<AttemptDetails, String>((ref, attemptId) async {
      final result = await ref
          .watch(performanceRepositoryProvider)
          .getAttemptDetails(attemptId);
      return _unwrap(result);
    });

/// `FutureProvider` wants a thrown error for its `AsyncError` state, not a
/// `Result.failure` — same seam as curriculum_providers.dart's `_unwrap`.
/// Accuracy per curriculum part, for the selected attempt type.
final partPerformanceProvider =
    FutureProvider.autoDispose<List<TopicPerformance>>((ref) async {
      final filter = ref.watch(performanceFilterProvider);
      final result = await ref
          .watch(performanceRepositoryProvider)
          .getPartPerformance(filter: filter);
      return _unwrap(result);
    });

/// Daily accuracy over the last 7 days (every attempt type).
final performanceTrendProvider = FutureProvider.autoDispose<List<TrendDay>>((
  ref,
) async {
  final result = await ref.watch(performanceRepositoryProvider).getTrend();
  return _unwrap(result);
});

T _unwrap<T>(Result<T> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
}
