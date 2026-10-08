/// The authoritative outcome of a completed session — always sourced from
/// the repository (backend, once it exists), never computed client-side.
/// The app does keep a local provisional answered/unanswered tally *during*
/// the session for progress UI, but once this arrives it's what the
/// Results screen shows (ARCHITECTURE.md: "do not calculate metrics
/// differently from the backend if authoritative results are provided").
class SessionResult {
  const SessionResult({
    required this.sessionId,
    required this.totalQuestions,
    required this.answered,
    required this.unanswered,
    required this.correct,
    required this.incorrect,
    required this.scorePercent,
    required this.totalTime,
    required this.averageTimePerQuestion,
  });

  final String sessionId;
  final int totalQuestions;
  final int answered;
  final int unanswered;
  final int correct;
  final int incorrect;
  final double scorePercent;
  final Duration totalTime;
  final Duration averageTimePerQuestion;
}
