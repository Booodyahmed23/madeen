import '../../../../core/network/api_client.dart';
import '../../../performance/domain/entities/attempt_type.dart';
import '../../../performance/domain/entities/performance_filter.dart';
import '../models/ai_analysis_model.dart';
import 'ai_analysis_data_source.dart';

/// Talks to the AI Analysis endpoints proposed in
/// AI_ANALYSIS_API_REQUIREMENTS.md (mobile/ root).
///
/// ⚠️ NOT YET INTEGRATION-TESTED AGAINST A REAL BACKEND — as of Phase 7,
/// backend/ has no AIAnalysis module (verified by inspection: only
/// `identity` and `notification` exist under backend/src/modules/). This
/// class exists so the mobile app's abstraction is ready the day those
/// endpoints ship; until then it is wired up but not selected by default —
/// see AppConfig.isAiAnalysisApiAvailable and ai_analysis_data_source.dart.
class AiAnalysisRemoteDataSource implements AiAnalysisDataSource {
  AiAnalysisRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Map<String, dynamic> _query(
    PerformanceFilter filter, {
    required String languageCode,
  }) {
    return {
      ...switch (filter.attemptType) {
        AttemptTypeFilter.all => const {},
        AttemptTypeFilter.studySession => {
          'attemptType': AttemptType.studySession.toWire(),
        },
        AttemptTypeFilter.examSimulation => {
          'attemptType': AttemptType.examSimulation.toWire(),
        },
      },
      'locale': languageCode,
    };
  }

  @override
  Future<AiAnalysisModel> getOverallAnalysis(
    PerformanceFilter filter, {
    required String languageCode,
  }) {
    return _apiClient.get(
      '/ai-analysis/overview',
      queryParameters: _query(filter, languageCode: languageCode),
      parse: (data) => AiAnalysisModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<AiAnalysisModel> getTopicAnalysis(
    String topicId, {
    required String languageCode,
  }) {
    return _apiClient.get(
      '/ai-analysis/topics/$topicId',
      queryParameters: {'locale': languageCode},
      parse: (data) => AiAnalysisModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<AiAnalysisModel> getAttemptAnalysis(
    String attemptId, {
    required String languageCode,
  }) {
    return _apiClient.get(
      '/ai-analysis/attempts/$attemptId',
      queryParameters: {'locale': languageCode},
      parse: (data) => AiAnalysisModel.fromJson(data as Map<String, dynamic>),
    );
  }
}
