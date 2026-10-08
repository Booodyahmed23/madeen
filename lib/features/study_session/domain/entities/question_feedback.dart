/// Immediate feedback for one answered question, read from the session the
/// server returned after the answer — never derived or guessed client-side.
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
