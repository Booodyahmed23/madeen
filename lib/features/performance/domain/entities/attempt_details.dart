import 'attempt_summary.dart';
import 'topic_performance.dart';

/// Full breakdown for one attempt — [summary] carries every field already
/// shown in Attempt History, extended here with the numbers only worth
/// fetching when a student drills in.
class AttemptDetails {
  const AttemptDetails({
    required this.summary,
    required this.unanswered,
    required this.wrong,
    required this.averageTimePerQuestion,
    this.topics = const [],
  });

  final AttemptSummary summary;
  final int unanswered;
  final int wrong;
  final Duration averageTimePerQuestion;

  /// Per-topic breakdown *for this one attempt*. Empty for an Exam
  /// Simulation attempt (exam questions carry no topic context, by design —
  /// see [TopicPerformance]'s doc comment) and for a Study Session attempt
  /// the backend hasn't computed a breakdown for yet — both are valid,
  /// handled empty states, not errors.
  final List<TopicPerformance> topics;
}
