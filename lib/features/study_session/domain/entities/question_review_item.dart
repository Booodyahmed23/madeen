import 'answer_choice.dart';

/// One question's full post-session review — everything here is only
/// available *after* submission, fetched fresh from the repository rather
/// than reconstructed from earlier [QuestionFeedback] responses, so the
/// Review screen never shows information the backend hasn't actually
/// confirmed for this session.
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
  final String correctChoiceId;

  /// `null` when the student left this question unanswered.
  final String? selectedChoiceId;
  final bool isCorrect;
  final String? explanation;
}
