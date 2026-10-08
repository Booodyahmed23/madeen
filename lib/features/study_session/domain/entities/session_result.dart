/// The outcome of a completed session, derived from the server's session
/// (see StudySession.toResult — contract §A3's result table).
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
