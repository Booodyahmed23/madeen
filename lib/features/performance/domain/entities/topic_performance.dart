/// Factual performance for one curriculum node the student has practiced.
/// Deliberately named `topicId`/`topicName` (matching the brief's own
/// vocabulary) but nothing here assumes the node is a `Topic` specifically —
/// the backend is free to aggregate at whatever level makes sense
/// (Program/Part/Unit/Sub-unit/Topic — see ARCHITECTURE.md's curriculum
/// hierarchy) as long as it returns one row per node with these fields.
///
/// Only ever populated from Study Session attempts: Exam Simulation
/// questions never carry curriculum/topic context, by design (see
/// docs/MOBILE_API_CONTRACT.md §A4), so there is nothing to aggregate
/// per-topic from an exam attempt.
class TopicPerformance {
  const TopicPerformance({
    required this.topicId,
    required this.topicName,
    required this.questionsAttempted,
    required this.answered,
    required this.correct,
    required this.wrong,
    this.averageTimePerQuestion,
  });

  final String topicId;
  final String topicName;
  final int questionsAttempted;
  final int answered;
  final int correct;
  final int wrong;

  /// `null` when the backend doesn't have enough timing data for this topic
  /// yet — not the same as zero seconds.
  final Duration? averageTimePerQuestion;

  /// Accuracy = Correct / Answered × 100 — the one formula used everywhere
  /// in this feature (see docs/MOBILE_API_CONTRACT.md §A5).
  /// Guards the zero-answered edge case (a topic touched but never actually
  /// answered) rather than dividing by zero.
  double get accuracyPercent => answered == 0 ? 0 : (correct / answered) * 100;

  /// A simple, documented accuracy threshold — explicitly **not** a
  /// weighted "weakness score" algorithm (out of scope this phase; see
  /// docs/MOBILE_API_CONTRACT.md §A5 and AI Analysis in
  /// ARCHITECTURE.md §17.2, which is a separate, later phase). A topic with
  /// no answered questions is neither strong nor needing practice — there
  /// is nothing to judge yet.
  static const double strongThreshold = 80;
  static const double needsPracticeThreshold = 60;

  bool get isStrong => answered > 0 && accuracyPercent >= strongThreshold;

  bool get needsPractice =>
      answered > 0 && accuracyPercent < needsPracticeThreshold;
}
