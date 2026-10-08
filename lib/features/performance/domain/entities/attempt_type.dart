/// Which mobile feature produced an attempt. Only these two exist today —
/// Study Session and Exam Simulation are the only two attempt-producing
/// features this phase (ARCHITECTURE.md's core loop also lists Course
/// quizzes as a future producer; adding one later is a new enum value here,
/// not a redesign).
enum AttemptType {
  studySession,
  examSimulation;

  /// Mirrors [ExamQuestionType.fromWire]'s style elsewhere in the app:
  /// gracefully handled by the repository's `_guard`, which turns a thrown
  /// [FormatException] into `UnknownFailure` rather than ever reaching the
  /// UI — see performance_repository_impl.dart.
  static AttemptType fromWire(String value) {
    switch (value) {
      case 'STUDY_SESSION':
        return AttemptType.studySession;
      case 'EXAM_SIMULATION':
        return AttemptType.examSimulation;
      default:
        throw FormatException('Unknown attempt type: $value');
    }
  }

  String toWire() => switch (this) {
    AttemptType.studySession => 'STUDY_SESSION',
    AttemptType.examSimulation => 'EXAM_SIMULATION',
  };
}
