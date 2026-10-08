/// One "what to do next" line in the Recommended Next Steps section.
/// [topicId]/[topicName], when present, let the presentation layer offer a
/// direct link into that topic's own AI Insight (see
/// presentation/screens/ai_analysis_overview_screen.dart) — a recommendation
/// with no topic reference (e.g. "keep up your current study routine") is
/// valid too and simply isn't tappable.
class AiRecommendation {
  const AiRecommendation({required this.text, this.topicId, this.topicName});

  final String text;
  final String? topicId;
  final String? topicName;
}
