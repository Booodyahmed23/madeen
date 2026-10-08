import '../../../../core/error/result.dart';
import '../entities/attempt_details.dart';
import '../entities/attempt_history_page.dart';
import '../entities/performance_filter.dart';
import '../entities/performance_overview.dart';
import '../entities/topic_performance.dart';

/// The mobile app's only window onto Performance Analytics data —
/// presentation code depends on this interface, never on a concrete data
/// source (see PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md at the repo root
/// of mobile/ for the proposed backend contract this mirrors). Deliberately
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
  /// PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md).
  Future<Result<AttemptHistoryPage>> getAttempts({
    PerformanceFilter filter = const PerformanceFilter(),
    int limit = 20,
    int offset = 0,
  });

  Future<Result<AttemptDetails>> getAttemptDetails(String attemptId);
}
