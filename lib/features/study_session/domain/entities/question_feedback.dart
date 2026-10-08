/// Returned by the repository after submitting one answer in Immediate
/// Feedback mode — the *only* place a correct-answer id or explanation is
/// allowed to reach the app, and only for the question just answered.
/// Never derived or guessed client-side (ARCHITECTURE.md's "never trust the
/// client as the authority for correct answers").
class QuestionFeedback {
  const QuestionFeedback({
    required this.questionId,
    required this.isCorrect,
    required this.correctChoiceId,
    this.explanation,
  });

  final String questionId;
  final bool isCorrect;
  final String correctChoiceId;
  final String? explanation;
}
