import 'ai_analysis_scope.dart';

/// Provenance for one [AiAnalysis] — never shown as the analysis itself, but
/// what the "Based on" section and the scope-specific screens use to explain
/// *what* was analyzed, matching the phase brief's "the user should
/// understand WHY the recommendation exists."
class AiAnalysisMetadata {
  const AiAnalysisMetadata({
    required this.scope,
    required this.status,
    required this.generatedAt,
    this.basedOnAttemptCount,
    this.topicId,
    this.attemptId,
  });

  final AiAnalysisScope scope;
  final AiAnalysisStatus status;

  /// When this analysis was produced — a mock-mode analysis is regenerated
  /// (and its content re-derived, deterministically, from the same
  /// Performance data) on every fetch, so this reflects fetch time, not a
  /// stored value; a real backend would persist it alongside the report
  /// (ARCHITECTURE.md §6.2's `AnalysisReport.generated_at`).
  final DateTime generatedAt;

  /// How many attempts fed this analysis — set only for [AiAnalysisScope.
  /// overall] (and, in future, [AiAnalysisScope.recent]), where "based on N
  /// attempts" is a meaningful, factual sentence. `null` for
  /// [AiAnalysisScope.topic]/[AiAnalysisScope.attempt], where the topic/
  /// attempt's own metrics (carried on [AiTopicInsight] or the attempt
  /// summary) already say what the analysis is grounded in — repeating an
  /// attempt count there would be redundant, not additional evidence.
  final int? basedOnAttemptCount;

  /// Set only when [scope] is [AiAnalysisScope.topic].
  final String? topicId;

  /// Set only when [scope] is [AiAnalysisScope.attempt].
  final String? attemptId;
}
