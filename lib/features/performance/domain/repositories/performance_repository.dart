import '../../../../core/error/result.dart';
import '../entities/attempt_details.dart';
import '../entities/attempt_history_page.dart';
import '../entities/performance_filter.dart';
import '../entities/performance_overview.dart';
import '../entities/topic_performance.dart';
import '../entities/trend_day.dart';

/// The mobile app's only window onto Performance Analytics data —
/// presentation code depends on this interface, never on a concrete data
/// source (the API it mirrors is docs/MOBILE_API_CONTRACT.md §A5). Deliberately
/// read-only: this feature never writes attempt data — Study Session and
/// Exam Simulation own that, independently (see this feature's README).
abstract class PerformanceRepository {
  Future<Result<PerformanceOverview>> getOverview({
    PerformanceFilter filter = const PerformanceFilter(),
  });

  /// Every topic the student has practiced at least once. `filter` here
  /// only affects `attemptType` (an exam never contributes topic rows —
  /// see [TopicPerformance]'s doc comment); `topicFilter` (Strong / Needs
  /// Practice) is applied client-side over the already-fetched list, not a
  /// separate query — see presentation/providers.
  Future<Result<List<TopicPerformance>>> getTopicPerformance({
    PerformanceFilter filter = const PerformanceFilter(),
  });

  /// Paginated Attempt History, most recent first. `limit`/`offset` keep
  /// this scalable rather than loading the whole history into memory (see
  /// docs/MOBILE_API_CONTRACT.md §A5).
  Future<Result<AttemptHistoryPage>> getAttempts({
    PerformanceFilter filter = const PerformanceFilter(),
    int limit = 20,
    int offset = 0,
  });

  Future<Result<AttemptDetails>> getAttemptDetails(String attemptId);

  /// Accuracy per curriculum part (contract §A5).
  Future<Result<List<TopicPerformance>>> getPartPerformance({
    PerformanceFilter filter = const PerformanceFilter(),
  });

  /// Daily accuracy for the last [days] days, oldest first.
  Future<Result<List<TrendDay>>> getTrend({int days = 7});
}
