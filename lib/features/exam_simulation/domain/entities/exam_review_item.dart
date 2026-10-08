import 'exam_answer_choice.dart';

/// One question's full post-exam review — only available *after*
/// submission, fetched fresh from the repository rather than reconstructed
/// from anything shown during the exam (nothing shown during the exam ever
/// carries this information — see [ExamQuestion]).
class ExamReviewItem {
  const ExamReviewItem({
    required this.questionId,
    required this.questionText,
    required this.choices,
    required this.correctChoiceId,
    required this.selectedChoiceId,
    required this.isCorrect,
    required this.wasFlagged,
    this.explanation,
    this.topicId,
    this.topicName,
  });

  final String questionId;
  final String questionText;
  final List<ExamAnswerChoice> choices;

  /// `null` only if the server didn't reveal the question.
  final String? correctChoiceId;

  /// `null` when the student left this question unanswered.
  final String? selectedChoiceId;
  final bool isCorrect;

  /// Whether the student had flagged this question during the exam — shown
  /// for the student's own reference only, never affects scoring.
  final bool wasFlagged;
  final String? explanation;

  /// The curriculum topic this question belongs to. Only ever revealed
  /// here, *after* submission — the in-exam [ExamQuestion] deliberately has
  /// no topic field. `null` when the server doesn't classify the question.
  final String? topicId;
  final String? topicName;

  /// Answered and wrong — an unanswered question is neither correct nor
  /// "wrong" in this sense (see [isUnanswered]).
  bool get isWrong => selectedChoiceId != null && !isCorrect;
  bool get isUnanswered => selectedChoiceId == null;
}
