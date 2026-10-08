import '../../domain/entities/attempt_type.dart';
import 'attempt_details_model.dart';
import 'attempt_summary_model.dart';
import 'topic_performance_model.dart';

/// One completed Study Session or Exam Simulation attempt, recorded on this
/// device — the mock-mode stand-in for what the backend's own submit
/// endpoints will record once the Performance API exists (see
/// PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md: Performance itself is
/// read-only, attempts are written by the practice flows). Only ever
/// created by the app-level practice recorder, and only while
/// `AppConfig.isPerformanceApiAvailable` is `false`.
///
/// Carries everything needed to rebuild the read models Performance already
/// serves: [toSummaryModel] (history/overview), [toDetailsModel] (Attempt
/// Details), and [toTopicModel] (topic aggregation). A data-layer model, not
/// a domain entity — no domain type changes for this.
class LocalAttemptRecord {
  const LocalAttemptRecord({
    required this.attemptId,
    required this.sourceId,
    required this.type,
    required this.completedAt,
    required this.contentLabel,
    required this.totalQuestions,
    required this.answered,
    required this.unanswered,
    required this.correct,
    required this.wrong,
    required this.scorePercent,
    required this.durationSeconds,
    required this.averageTimePerQuestionSeconds,
    this.topicId,
    this.topicName,
    this.topics = const [],
  });

  factory LocalAttemptRecord.fromJson(Map<String, dynamic> json) {
    return LocalAttemptRecord(
      attemptId: json['attemptId'] as String,
      sourceId: json['sourceId'] as String,
      type: AttemptType.fromWire(json['type'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      contentLabel: json['contentLabel'] as String,
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      answered: (json['answered'] as num).toInt(),
      unanswered: (json['unanswered'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      wrong: (json['wrong'] as num).toInt(),
      scorePercent: (json['scorePercent'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      averageTimePerQuestionSeconds:
          (json['averageTimePerQuestionSeconds'] as num).toInt(),
      topicId: json['topicId'] as String?,
      topicName: json['topicName'] as String?,
      // Absent in records persisted before Phase 15 — those simply have no
      // per-topic rows.
      topics: [
        for (final topic in (json['topics'] as List?) ?? const [])
          TopicPerformanceModel.fromJson(topic as Map<String, dynamic>),
      ],
    );
  }

  /// `local-<sourceId>-<µs since epoch>`. The mock practice data sources
  /// restart their own ids (`mock-session-0`, `mock-attempt-0`, …) on every
  /// launch, so [sourceId] alone would collide with attempts persisted by
  /// an earlier launch — and with the `/performance/attempts/:id` route.
  static String idFor(String sourceId, DateTime completedAt) =>
      'local-$sourceId-${completedAt.microsecondsSinceEpoch}';

  /// Unique across launches — see [idFor].
  final String attemptId;

  /// The id the practice flow itself used (session/attempt id) — kept for
  /// traceability only; never used as a key.
  final String sourceId;
  final AttemptType type;
  final DateTime completedAt;
  final String contentLabel;
  final int totalQuestions;
  final int answered;
  final int unanswered;
  final int correct;
  final int wrong;
  final double scorePercent;
  final int durationSeconds;
  final int averageTimePerQuestionSeconds;

  /// Study Session only — the session's single topic. Exam records leave
  /// both `null` and carry [topics] instead.
  final String? topicId;
  final String? topicName;

  /// Exam Simulation only — the per-topic breakdown of a submitted
  /// simulation (from its post-submission review; never shown during the
  /// exam). Empty for Study Sessions and for exams whose questions carry no
  /// topic.
  final List<TopicPerformanceModel> topics;

  Map<String, dynamic> toJson() => {
    'attemptId': attemptId,
    'sourceId': sourceId,
    'type': type.toWire(),
    'completedAt': completedAt.toIso8601String(),
    'contentLabel': contentLabel,
    'totalQuestions': totalQuestions,
    'answered': answered,
    'unanswered': unanswered,
    'correct': correct,
    'wrong': wrong,
    'scorePercent': scorePercent,
    'durationSeconds': durationSeconds,
    'averageTimePerQuestionSeconds': averageTimePerQuestionSeconds,
    'topicId': topicId,
    'topicName': topicName,
    'topics': [for (final topic in topics) topic.toJson()],
  };

  AttemptSummaryModel toSummaryModel() => AttemptSummaryModel(
    attemptId: attemptId,
    type: type,
    completedAt: completedAt,
    contentLabel: contentLabel,
    totalQuestions: totalQuestions,
    answered: answered,
    correct: correct,
    scorePercent: scorePercent,
    durationSeconds: durationSeconds,
  );

  /// This attempt's topic rows: a Study Session's single topic, or an
  /// exam's per-topic breakdown ([topics]).
  List<TopicPerformanceModel> toTopicModels() {
    final topicId = this.topicId;
    if (topicId == null) return topics;
    return [
      TopicPerformanceModel(
        topicId: topicId,
        topicName: topicName ?? contentLabel,
        questionsAttempted: totalQuestions,
        answered: answered,
        correct: correct,
        wrong: wrong,
        averageTimePerQuestionSeconds: averageTimePerQuestionSeconds,
      ),
    ];
  }

  AttemptDetailsModel toDetailsModel() {
    return AttemptDetailsModel(
      summary: toSummaryModel(),
      unanswered: unanswered,
      wrong: wrong,
      averageTimePerQuestionSeconds: averageTimePerQuestionSeconds,
      topics: toTopicModels(),
    );
  }
}
