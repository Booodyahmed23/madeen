/// Which attempt type(s) a screen is scoped to. Filtering logic lives in
/// the provider layer (see presentation/providers), never in widgets.
enum AttemptTypeFilter { all, studySession, examSimulation }

/// Simple, factual bucketing for the Topic Performance screen — backed by
/// [TopicPerformance.isStrong]/[TopicPerformance.needsPractice], not a
/// separate scoring algorithm.
enum TopicPerformanceFilter { all, strong, needsPractice }

/// Immutable filter state shared by every Performance screen. A single
/// class (rather than separate provider state per screen) because Overview,
/// Topic Performance, and Attempt History all read/write the same
/// `attemptType` selection — keeping them in sync is the point.
class PerformanceFilter {
  const PerformanceFilter({
    this.attemptType = AttemptTypeFilter.all,
    this.topicFilter = TopicPerformanceFilter.all,
  });

  final AttemptTypeFilter attemptType;
  final TopicPerformanceFilter topicFilter;

  PerformanceFilter copyWith({
    AttemptTypeFilter? attemptType,
    TopicPerformanceFilter? topicFilter,
  }) {
    return PerformanceFilter(
      attemptType: attemptType ?? this.attemptType,
      topicFilter: topicFilter ?? this.topicFilter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PerformanceFilter &&
      other.attemptType == attemptType &&
      other.topicFilter == topicFilter;

  @override
  int get hashCode => Object.hash(attemptType, topicFilter);
}
