import '../../../../core/error/result.dart';
import '../../../performance/domain/entities/performance_filter.dart';
import '../entities/ai_analysis.dart';

/// The mobile app's only window onto AI-Powered Performance Analysis —
/// presentation code depends on this interface, never on a concrete data
/// source (see AI_ANALYSIS_API_REQUIREMENTS.md at the repo root of mobile/
/// for the proposed backend contract this mirrors, and this feature's
/// README for why it legitimately depends on [PerformanceFilter] from the
/// Performance feature rather than duplicating it).
///
/// Deliberately read-only, same posture as PerformanceRepository: this
/// feature never writes anything, and every method call is a *request to
/// generate/fetch an explanation*, never a mutation of the underlying
/// Performance data.
abstract class AiAnalysisRepository {
  /// AI analysis over every attempt [filter] selects — the "Performance →
  /// AI Analysis" entry point from Performance Overview.
  Future<Result<AiAnalysis>> getOverallAnalysis({
    PerformanceFilter filter = const PerformanceFilter(),
    required String languageCode,
  });

  /// AI analysis for exactly one topic — the "Topic Details → Analyze with
  /// AI" entry point from Topic Performance.
  Future<Result<AiAnalysis>> getTopicAnalysis({
    required String topicId,
    required String languageCode,
  });

  /// AI analysis for exactly one completed attempt — the "Attempt Details →
  /// Analyze with AI" entry point.
  Future<Result<AiAnalysis>> getAttemptAnalysis({
    required String attemptId,
    required String languageCode,
  });
}
