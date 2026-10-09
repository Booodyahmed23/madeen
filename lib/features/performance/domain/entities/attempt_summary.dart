import 'attempt_type.dart';

/// One row in the Attempt History list — always sourced from the
/// repository (backend, once it exists), never computed client-side, same
/// authoritative-numbers rule as [SessionResult]/[ExamResult] in the
/// features this data is drawn from.
class AttemptSummary {
  const AttemptSummary({
    required this.attemptId,
    required this.type,
    required this.completedAt,
    required this.contentLabel,
    required this.totalQuestions,
    required this.answered,
    required this.correct,
    required this.scorePercent,
    required this.duration,
  });

  final String attemptId;
  final AttemptType type;
  final DateTime completedAt;

  /// Human-readable label for what this attempt covered — a topic name for
  /// a Study Session (e.g. "Budgeting"), or a "Program Part" label for an
  /// Exam Simulation (e.g. "CMA Part 1"). Resolved server-side (or by the
  /// mock data source); never hardcoded to one certification's vocabulary
  /// here.
  final String contentLabel;

  final int totalQuestions;
  final int answered;
  final int correct;

  /// Score = Correct / Total Questions × 100 (unanswered count against the
  /// score, matching how SessionResult/ExamResult already compute it) —
  /// distinct from [accuracyPercent] below, which is answered-only. Both
  /// are shown so a student can tell "I got 70% overall" apart from "of
  /// what I actually answered, I got 90% right."
  final double scorePercent;

  final Duration duration;

  /// Accuracy = Correct / Answered × 100 — see
  /// docs/MOBILE_API_CONTRACT.md §A5 for why this is the one
  /// formula used everywhere accuracy is shown.
  double get accuracyPercent => answered == 0 ? 0 : (correct / answered) * 100;
}
