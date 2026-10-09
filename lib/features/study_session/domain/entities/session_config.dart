/// `IMMEDIATE` (each answer is revealed once given) or `DEFERRED` (revealed
/// when the session is completed).
enum FeedbackMode { immediate, atEnd }

/// The API's question difficulty (`EASY` | `MEDIUM` | `HARD`).
enum QuestionDifficulty {
  easy,
  medium,
  hard;

  String toWire() => name.toUpperCase();
}

/// Question-count presets the Setup screen offers; any count from
/// [kMinQuestionCount] to [kMaxQuestionCount] is valid.
const List<int> kQuestionCountOptions = [10, 20, 30, 40, 50];
const kMinQuestionCount = 1;
const kMaxQuestionCount = 100;

/// What the student configured before starting. A session covers one
/// topic (reached from a Topic in Curriculum), several (a whole
/// sub-unit), or — with no topic ids — every topic the student has access
/// to (contract §A3/§A8 B7). There is no question-order option: the server
/// always shuffles.
class SessionConfig {
  const SessionConfig({
    this._topicId,
    this._topicIds = const [],
    required this.topicName,
    required this.questionCount,
    required this.feedbackMode,
    this.difficulty,
  });

  final String? _topicId;
  final List<String> _topicIds;

  /// What the session is shown as (a topic or sub-unit name, or "All my
  /// topics").
  final String topicName;
  final int questionCount;
  final FeedbackMode feedbackMode;

  /// `null` = any difficulty.
  final QuestionDifficulty? difficulty;

  /// The topics to draw from; empty = all the student's topics.
  List<String> get topicIds => _topicIds.isNotEmpty ? _topicIds : [?_topicId];

  /// The single topic, when the session is about exactly one.
  String? get topicId => topicIds.length == 1 ? topicIds.single : null;
}
