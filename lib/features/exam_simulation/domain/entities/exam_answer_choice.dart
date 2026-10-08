/// One selectable option for an exam question. Deliberately its own type
/// rather than reusing study_session's `AnswerChoice` — Exam Simulation and
/// Study Session are architecturally separate experiences (see this
/// feature's README) and must not develop a hidden coupling just because
/// today's shape happens to match. If a real shared abstraction earns its
/// keep later, extract it then.
class ExamAnswerChoice {
  const ExamAnswerChoice({
    required this.id,
    required this.text,
    this.order = 0,
  });

  final String id;
  final String text;
  final int order;
}
