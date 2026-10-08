/// Only single-answer multiple choice is supported this phase — mirrors
/// study_session's QuestionType extension point, kept as its own enum so a
/// future exam-only question type (e.g. case-based) doesn't have to be
/// meaningful for Study Session too.
enum ExamQuestionType {
  multipleChoiceSingle;

  static ExamQuestionType fromWire(String value) {
    switch (value) {
      case 'MULTIPLE_CHOICE_SINGLE':
        return ExamQuestionType.multipleChoiceSingle;
      default:
        return ExamQuestionType.multipleChoiceSingle;
    }
  }
}
