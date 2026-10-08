import 'ai_analysis_metadata.dart';
import 'ai_insight.dart';
import 'ai_recommendation.dart';
import 'ai_topic_insight.dart';

/// One AI-generated performance analysis — the single shape reused across
/// every scope ([AiAnalysisMetadata.scope]: overall / topic / attempt /
/// recent), per this feature's README. This is an *interpretation* layer:
/// every number reachable from this entity (on [AiInsight.
/// supportingMetricPercent] and [AiTopicInsight]) is a value already shown
/// on a Performance Analytics screen, carried here as supporting evidence —
/// [AiAnalysis] itself never originates a score, accuracy, or count (see
/// PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md for the one place those numbers
/// come from, and AI_ANALYSIS_API_REQUIREMENTS.md for how this entity's
/// backend would be required to source them the same way).
class AiAnalysis {
  const AiAnalysis({
    required this.metadata,
    required this.overallSummary,
    this.strengths = const [],
    this.weaknesses = const [],
    this.topicInsights = const [],
    this.recurringPatterns = const [],
    this.recommendations = const [],
  });

  final AiAnalysisMetadata metadata;

  /// The "Overall Analysis" / "AI Insight" paragraph — for
  /// [AiAnalysisMetadata.status] = [AiAnalysisStatus.insufficientData], this
  /// is the empty-state explanation shown instead (e.g. "complete a study
  /// session to unlock personalized insights"), not a claim about data that
  /// doesn't exist yet.
  final String overallSummary;

  final List<AiInsight> strengths;
  final List<AiInsight> weaknesses;

  /// Per-topic breakdown — every topic in scope for [AiAnalysisScope.
  /// overall], or exactly one topic for [AiAnalysisScope.topic]/[
  /// AiAnalysisScope.attempt] (when that attempt has topic data at all —
  /// see AttemptDetails.topics).
  final List<AiTopicInsight> topicInsights;

  final List<AiInsight> recurringPatterns;
  final List<AiRecommendation> recommendations;

  /// Whether there is anything beyond [overallSummary] to render — the
  /// presentation layer uses this instead of separately checking every list
  /// (see ai_analysis_overview_screen.dart).
  bool get hasInsights =>
      strengths.isNotEmpty ||
      weaknesses.isNotEmpty ||
      topicInsights.isNotEmpty ||
      recurringPatterns.isNotEmpty ||
      recommendations.isNotEmpty;
}
