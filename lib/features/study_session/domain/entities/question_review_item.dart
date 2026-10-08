import 'answer_choice.dart';

/// One question's post-session review, built from the completed session
/// the server returns — never reconstructed from what was shown during the
/// session.
class QuestionReviewItem {
  const QuestionReviewItem({
    required this.questionId,
    required this.questionText,
    required this.choices,
    required this.correctChoiceId,
    required this.selectedChoiceId,
    required this.isCorrect,
    this.explanation,
  });

  final String questionId;
  final String questionText;
  final List<AnswerChoice> choices;

  /// `null` when the server didn't reveal this question (a skipped question,
  /// on servers that reveal only answered ones).
  final String? correctChoiceId;

  /// `null` when the student left this question unanswered.
  final String? selectedChoiceId;

  /// `null` for a skipped question.
  final bool? isCorrect;
  final String? explanation;

  bool get isSkipped => selectedChoiceId == null;
}
