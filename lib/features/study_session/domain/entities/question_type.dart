/// Only single-answer multiple choice is supported this phase. The enum
/// exists (rather than assuming one hardcoded shape everywhere) so future
/// types — multiple-response, calculation, case-based, image-based — are
/// additive: a new enum value, a new choice-rendering widget, and nothing
/// about [AnswerChoice]/[Question]'s other fields has to change. See
/// ARCHITECTURE.md §9's "renderer registry" pattern, applied here.
enum QuestionType {
  multipleChoiceSingle;

  static QuestionType fromWire(String value) {
    switch (value) {
      case 'MULTIPLE_CHOICE_SINGLE':
        return QuestionType.multipleChoiceSingle;
      default:
        // Unknown/future type from a newer backend — degrade to the one
        // shape this client knows how to render rather than crash.
        return QuestionType.multipleChoiceSingle;
    }
  }
}
