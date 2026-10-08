/// One selectable option for a question — deliberately carries no
/// correctness information. What the student sees while answering and what
/// the backend later confirms as correct are two different types
/// ([AnswerChoice] vs. the correct-choice id inside [QuestionFeedback]) so
/// there is no field to accidentally leak early, even by a coding mistake.
class AnswerChoice {
  const AnswerChoice({required this.id, required this.text, this.order = 0});

  final String id;
  final String text;
  final int order;
}
