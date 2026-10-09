/// High-level summary shown at the top of the Performance Overview screen —
/// always sourced from the repository, aggregated server-side once the
/// backend exists (see docs/MOBILE_API_CONTRACT.md §A5).
class PerformanceOverview {
  const PerformanceOverview({
    required this.totalAttempts,
    required this.questionsPracticed,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.overallScorePercent,
    required this.totalTime,
    required this.averageTimePerQuestion,
  });

  final int totalAttempts;
  final int questionsPracticed;
  final int totalAnswered;
  final int totalCorrect;

  /// Correct / Questions Practiced × 100 — mirrors
  /// [AttemptSummary.scorePercent] (unanswered counts against it).
  final double overallScorePercent;

  final Duration totalTime;
  final Duration averageTimePerQuestion;

  /// Accuracy = Correct / Answered × 100 — see
  /// docs/MOBILE_API_CONTRACT.md §A5. Guards the zero-attempts
  /// edge case.
  double get overallAccuracyPercent =>
      totalAnswered == 0 ? 0 : (totalCorrect / totalAnswered) * 100;
}
