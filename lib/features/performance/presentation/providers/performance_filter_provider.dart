import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/performance_filter.dart';

/// The one filter state every Performance screen reads/writes — Overview,
/// Topic Performance, and Attempt History all stay in sync on `attemptType`
/// because they share this provider rather than each keeping its own copy.
class PerformanceFilterNotifier extends Notifier<PerformanceFilter> {
  @override
  PerformanceFilter build() => const PerformanceFilter();

  void setAttemptType(AttemptTypeFilter type) {
    state = state.copyWith(attemptType: type);
  }

  void setTopicFilter(TopicPerformanceFilter filter) {
    state = state.copyWith(topicFilter: filter);
  }
}

final performanceFilterProvider =
    NotifierProvider<PerformanceFilterNotifier, PerformanceFilter>(
      PerformanceFilterNotifier.new,
    );
