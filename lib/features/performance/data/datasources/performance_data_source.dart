import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../domain/entities/performance_filter.dart';
import '../models/attempt_details_model.dart';
import '../models/attempt_history_page_model.dart';
import '../models/performance_overview_model.dart';
import '../models/topic_performance_model.dart';
import '../local_attempts_provider.dart';
import 'performance_mock_data_source.dart';
import 'performance_remote_data_source.dart';

/// Shape both [PerformanceRemoteDataSource] (real backend, once it exists —
/// see PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md) and
/// [PerformanceMockDataSource] (deterministic local sample data, used until
/// then) implement. PerformanceRepositoryImpl depends on this interface,
/// not on either concrete implementation — mirrors curriculum/study-session/
/// exam-simulation's own data source pattern exactly.
abstract class PerformanceDataSource {
  Future<PerformanceOverviewModel> getOverview(PerformanceFilter filter);

  Future<List<TopicPerformanceModel>> getTopicPerformance(
    PerformanceFilter filter,
  );

  Future<AttemptHistoryPageModel> getAttempts(
    PerformanceFilter filter, {
    required int limit,
    required int offset,
  });

  Future<AttemptDetailsModel> getAttemptDetails(String attemptId);
}

/// The single switch between real and sample Performance Analytics data.
/// See AppConfig.isPerformanceApiAvailable and
/// PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md — flipping the
/// `PERFORMANCE_API_AVAILABLE` dart-define is the only change needed once
/// the backend ships these endpoints.
///
/// In mock mode the data source is rebuilt whenever [localAttemptsProvider]
/// changes — that single dependency is what makes a newly completed
/// practice attempt flow through the repository into every Performance and
/// AI Analysis provider (and Home) with no manual refresh. In API mode,
/// local attempts are never read: the backend is the only source of truth,
/// so nothing can be double-counted.
final performanceDataSourceProvider = Provider<PerformanceDataSource>((ref) {
  if (ref.watch(performanceApiAvailableProvider)) {
    return PerformanceRemoteDataSource(
      ref.watch(apiClientProvider),
      labelTopics: (topicIds) => _labelTopics(ref, topicIds),
    );
  }
  return PerformanceMockDataSource(
    localAttempts: ref.watch(localAttemptsProvider),
  );
});

/// [AppConfig.isPerformanceApiAvailable] as a provider — the one place the
/// Performance feature and the practice recorder read it from, so tests can
/// prove both the mock-mode merge and the API-mode "never record, never
/// merge" behavior (a compile-time constant alone can't be flipped in a
/// test).
/// "First topic +N", with names from the curriculum. A topic the student
/// can't see any more is left out of the name but still counted.
Future<String> _labelTopics(Ref ref, List<String> topicIds) async {
  if (topicIds.isEmpty) return '';
  String? first;
  for (final id in topicIds) {
    try {
      first = await ref.read(topicNameProvider(id).future);
    } catch (_) {
      first = null;
    }
    if (first != null) break;
  }
  if (first == null) return '';
  return topicIds.length == 1 ? first : '$first +${topicIds.length - 1}';
}

final performanceApiAvailableProvider = Provider<bool>(
  (ref) => AppConfig.isPerformanceApiAvailable,
);
