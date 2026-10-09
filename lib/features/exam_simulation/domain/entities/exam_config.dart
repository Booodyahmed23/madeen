/// Question-count presets offered on the Setup screen, each paired with
/// its countdown in [examDurationFor].
///
/// **These are mobile-side placeholders, not the official CMA/FMAA exam
/// question counts or time limits.** The real per-part values are a
/// certification business rule that must come from the backend once
/// docs/MOBILE_API_CONTRACT.md §A4's endpoints exist — and the server
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

/// The API's question difficulty (`EASY` | `MEDIUM` | `HARD`) for an exam.
enum ExamDifficulty {
  easy,
  medium,
  hard;

  String toWire() => name.toUpperCase();
}

/// What the student configured on Exam Setup: a Program + Part, optionally
/// narrowed to a Unit and Sub-unit, and the question count (which sets the
/// time limit). There is no question-order option: the server always
/// shuffles.
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
    required this.topicIds,
    this.topicNames = const {},
    this.difficulty,
  });

  /// `null` = any difficulty.
  final ExamDifficulty? difficulty;

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

  /// The topics under the selected node, resolved from the curriculum tree
  /// — what the API is actually sent (contract §A4).
  final List<String> topicIds;

  /// Names for [topicIds], for sample data only — the API sends its own.
  final Map<String, String> topicNames;

  /// `clamp(ceil(seconds / 60), 5, 300)` — the API takes whole minutes.
  int get durationMinutes => (duration.inSeconds / 60).ceil().clamp(5, 300);
}
