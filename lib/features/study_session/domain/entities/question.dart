import 'answer_choice.dart';
import 'question_type.dart';

/// The question **as presented to the student** — the correct answer,
/// explanation, and any "is this correct" information deliberately do not
/// exist on this type. Those only ever arrive via [QuestionFeedback] (after
/// an immediate-feedback submission) or [QuestionReviewItem] (after the
/// session ends), both fetched from the repository, never derived
/// client-side. See mobile/STUDY_SESSION_API_REQUIREMENTS.md.
class Question {
  const Question({
    required this.id,
    required this.text,
    required this.type,
    required this.choices,
    this.difficulty,
    this.code,
    this.losCode,
  });

  final String id;
  final String text;
  final QuestionType type;
  final List<AnswerChoice> choices;
  final String? difficulty;

  /// The bank's question number and LOS (learning outcome statement) code
  /// — a reference students can quote when asking about a question.
  final int? code;
  final String? losCode;

  /// `#101 · LOS 1.A`, or `null` when there's neither.
  String? get reference {
    final parts = [if (code != null) '#$code', ?losCode];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
