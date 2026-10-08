/// One topic's factual metrics plus the AI's interpretation of them — the
/// shape both the Overall Analysis screen's "Topic Insights" section and the
/// dedicated Topic AI Insight screen render (see this feature's README on
/// why there is only one shape rather than a screen-specific one).
///
/// [accuracyPercent]/[answered]/[correct] are a snapshot of the same
/// factual numbers [TopicPerformance] exposes, carried here rather than
/// re-fetched by the presentation layer — this is deliberate: an AI
/// analysis is generated at a point in time, and [interpretation] is a
/// claim *about* these exact numbers, so the numbers must travel with the
/// claim (ARCHITECTURE.md §17.2's "numbers included in the output so a
/// student can verify the claim"), not be re-read live from
/// TopicPerformance afterwards where they could have since changed.
class AiTopicInsight {
  const AiTopicInsight({
    required this.topicId,
    required this.topicName,
    required this.accuracyPercent,
    required this.answered,
    required this.correct,
    required this.interpretation,
    required this.recommendedAction,
  });

  final String topicId;
  final String topicName;
  final double accuracyPercent;
  final int answered;
  final int correct;

  /// "Why this matters" — a data-grounded interpretation, phrased with
  /// hedged language ("your recent results suggest...") rather than an
  /// authoritative diagnosis (see this feature's README / the phase brief's
  /// "AI principles").
  final String interpretation;

  /// A concrete, actionable next step — never generic motivational text
  /// (ARCHITECTURE.md §17.2).
  final String recommendedAction;
}
