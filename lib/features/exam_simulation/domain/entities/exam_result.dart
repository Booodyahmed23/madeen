/// The authoritative outcome of a submitted exam attempt — always sourced
/// from the repository (backend, once it exists), never computed
/// client-side. Flagged-question count is not part of the score (flagging
/// is a review/navigation aid only — see ExamSimulationNotifier.toggleFlag)
/// and is therefore not part of this authoritative result either.
class ExamResult {
  const ExamResult({
    required this.attemptId,
    required this.totalQuestions,
    required this.answered,
    required this.unanswered,
    required this.correct,
    required this.incorrect,
    required this.scorePercent,
    required this.durationTaken,
    required this.completionStatus,
  });

  final String attemptId;
  final int totalQuestions;
  final int answered;
  final int unanswered;
  final int correct;
  final int incorrect;
  final double scorePercent;
  final Duration durationTaken;

  /// Server-reported completion status (e.g. "completed" vs "timed_out") —
  /// an opaque string rather than a client-defined enum, since the set of
  /// values is a backend decision this app doesn't get to make yet. See
  /// EXAM_SIMULATION_API_REQUIREMENTS.md.
  final String completionStatus;
}
