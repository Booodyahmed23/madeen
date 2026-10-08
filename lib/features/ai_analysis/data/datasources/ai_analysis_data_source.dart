import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../performance/data/repositories/performance_repository_impl.dart';
import '../../../performance/domain/entities/performance_filter.dart';
import '../models/ai_analysis_model.dart';
import 'ai_analysis_mock_data_source.dart';
import 'ai_analysis_remote_data_source.dart';

/// Shape both [AiAnalysisRemoteDataSource] (real backend, once it exists —
/// see AI_ANALYSIS_API_REQUIREMENTS.md) and [AiAnalysisMockDataSource]
/// (deterministic content derived from the same Performance Analytics
/// numbers already on screen) implement. AiAnalysisRepositoryImpl depends on
/// this interface, not on either concrete implementation — mirrors
/// performance_data_source.dart's own pattern exactly.
abstract class AiAnalysisDataSource {
  Future<AiAnalysisModel> getOverallAnalysis(
    PerformanceFilter filter, {
    required String languageCode,
  });

  Future<AiAnalysisModel> getTopicAnalysis(
    String topicId, {
    required String languageCode,
  });

  Future<AiAnalysisModel> getAttemptAnalysis(
    String attemptId, {
    required String languageCode,
  });
}

/// The single switch between real and sample AI Analysis data. See
/// AppConfig.isAiAnalysisApiAvailable and AI_ANALYSIS_API_REQUIREMENTS.md —
/// flipping the `AI_ANALYSIS_API_AVAILABLE` dart-define is the only change
/// needed once the backend ships these endpoints. Note this is independent
/// of `PERFORMANCE_API_AVAILABLE`: the mock AI datasource reads through
/// [performanceRepositoryProvider] regardless of which Performance
/// datasource backs it, so "real Performance data, mock AI analysis" is a
/// valid intermediate deployment state.
final aiAnalysisDataSourceProvider = Provider<AiAnalysisDataSource>((ref) {
  if (AppConfig.isAiAnalysisApiAvailable) {
    return AiAnalysisRemoteDataSource(ref.watch(apiClientProvider));
  }
  return AiAnalysisMockDataSource(ref.watch(performanceRepositoryProvider));
});
