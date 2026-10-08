import '../../../../core/network/api_client.dart';
import '../../domain/entities/attempt_type.dart';
import '../../domain/entities/performance_filter.dart';
import '../models/attempt_details_model.dart';
import '../models/attempt_history_page_model.dart';
import '../models/performance_overview_model.dart';
import '../models/topic_performance_model.dart';
import 'performance_data_source.dart';

/// Talks to the Performance Analytics endpoints proposed in
/// PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md (mobile/ root).
///
/// ⚠️ NOT YET INTEGRATION-TESTED AGAINST A REAL BACKEND — as of Phase 6,
/// backend/ has no Performance/Analytics module (verified by inspection:
/// only `identity` and `notification` exist under
/// backend/src/modules/). This class exists so the mobile app's
/// abstraction is ready the day those endpoints ship; until then it is
/// wired up but not selected by default — see
/// AppConfig.isPerformanceApiAvailable and performance_data_source.dart.
class PerformanceRemoteDataSource implements PerformanceDataSource {
  PerformanceRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Map<String, dynamic> _attemptTypeQuery(PerformanceFilter filter) {
    return switch (filter.attemptType) {
      AttemptTypeFilter.all => const {},
      AttemptTypeFilter.studySession => {
        'attemptType': AttemptType.studySession.toWire(),
      },
      AttemptTypeFilter.examSimulation => {
        'attemptType': AttemptType.examSimulation.toWire(),
      },
    };
  }

  @override
  Future<PerformanceOverviewModel> getOverview(PerformanceFilter filter) {
    return _apiClient.get(
      '/performance/overview',
      queryParameters: _attemptTypeQuery(filter),
      parse: (data) =>
          PerformanceOverviewModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<List<TopicPerformanceModel>> getTopicPerformance(
    PerformanceFilter filter,
  ) {
    return _apiClient.get(
      '/performance/topics',
      queryParameters: _attemptTypeQuery(filter),
      parse: (data) => (data as List)
          .map(
            (json) =>
                TopicPerformanceModel.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  Future<AttemptHistoryPageModel> getAttempts(
    PerformanceFilter filter, {
    required int limit,
    required int offset,
  }) {
    return _apiClient.get(
      '/performance/attempts',
      queryParameters: {
        ..._attemptTypeQuery(filter),
        'limit': limit,
        'offset': offset,
      },
      parse: (data) =>
          AttemptHistoryPageModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<AttemptDetailsModel> getAttemptDetails(String attemptId) {
    return _apiClient.get(
      '/performance/attempts/$attemptId',
      parse: (data) =>
          AttemptDetailsModel.fromJson(data as Map<String, dynamic>),
    );
  }
}
