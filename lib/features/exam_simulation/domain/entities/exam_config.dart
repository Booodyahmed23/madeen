/// Question-count presets offered on the Setup screen, each paired with
/// its countdown in [examDurationFor].
///
/// **These are mobile-side placeholders, not the official CMA/FMAA exam
/// question counts or time limits.** The real per-part values are a
/// certification business rule that must come from the backend once
/// EXAM_SIMULATION_API_REQUIREMENTS.md's endpoints exist — and the server
/// stays authoritative for the duration of any attempt it starts (see
/// [ExamAttempt.durationSeconds]).
const List<int> kExamQuestionCountOptions = [10, 20, 50, 80];

const Map<int, Duration> _presetDurations = {
  10: Duration(minutes: 15),
  20: Duration(minutes: 30),
  50: Duration(minutes: 60),
  80: Duration(minutes: 120),
};

/// The countdown requested for a [questionCount]-question simulation — the
/// preset pairing above, or 90 seconds per question for any other count.
/// The student never picks a duration independently: like the real exam,
/// the time budget follows from the exam's length.
Duration examDurationFor(int questionCount) =>
    _presetDurations[questionCount] ?? Duration(seconds: questionCount * 90);

/// The order questions are served in. A request to the server, which
/// decides the actual order it returns (see [ExamAttempt.questions]).
enum ExamQuestionOrder {
  original,
  random;

  String toWire() => switch (this) {
    ExamQuestionOrder.original => 'original',
    ExamQuestionOrder.random => 'random',
  };
}

/// What the student configured before starting. The exam is scoped to a
/// certification Program + Part (the level real exams are organized at),
/// optionally narrowed to one Unit and, within it, one Sub-unit.
/// `questionCount`/`duration` follow the presets above until the backend
/// defines the real values. The server response to "start exam" is what
/// actually determines the questions and the authoritative duration — see
/// [ExamAttempt] — this config is only the client's *request*.
///
/// The scope names travel with the config for result/analytics labels
/// only; they are never shown while the exam is in progress (exam mode
/// has no topic/content display).
class ExamConfig {
  const ExamConfig({
    required this.programId,
    required this.programName,
    required this.partId,
    required this.partName,
    required this.questionCount,
    required this.duration,
    this.unitId,
    this.unitName,
    this.subUnitId,
    this.subUnitName,
    this.questionOrder = ExamQuestionOrder.original,
  });

  final String programId;
  final String programName;
  final String partId;
  final String partName;
  final int questionCount;
  final Duration duration;

  /// `null` = the whole Part.
  final String? unitId;
  final String? unitName;

  /// `null` = the whole Unit (always `null` when [unitId] is).
  final String? subUnitId;
  final String? subUnitName;

  final ExamQuestionOrder questionOrder;
}
