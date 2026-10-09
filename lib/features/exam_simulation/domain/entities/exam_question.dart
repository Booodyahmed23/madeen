import 'exam_answer_choice.dart';
import 'exam_question_type.dart';

/// The question **as presented to the student during the active exam**.
///
/// Two things are deliberately absent, both as exam-mode security/UX rules
/// enforced by the type itself rather than by convention:
/// - no correct-answer indicator or explanation (same reasoning as
///   study_session's `Question` — see docs/MOBILE_API_CONTRACT.md §A4)
/// - no topic/curriculum context of any kind (program/part/unit/sub-unit/
///   topic name or id) — the exam-mode rule is "no topic display", and a
///   field that isn't on the type can't be accidentally rendered
class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.choices,
  });

  final String id;
  final String text;
  final ExamQuestionType type;
  final List<ExamAnswerChoice> choices;
}
