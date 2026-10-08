import '../../domain/entities/session_config.dart';
import '../../domain/entities/study_session.dart';

/// JSON → domain for the API's study Session object and list rows
/// (contract §A3). The only place that knows these key names and the
/// UPPER_SNAKE enum values (§G6).
StudySession studySessionFromJson(Map<String, dynamic> json) {
  final progress = json['progress'] as Map<String, dynamic>;
  return StudySession(
    id: json['id'] as String,
    status: studySessionStatusFromWire(json['status'] as String),
    feedbackMode: feedbackModeFromWire(json['feedbackMode'] as String),
    topicIds: (json['topicIds'] as List).cast<String>(),
    difficulty: json['difficulty'] as String?,
    requestedCount: (json['requestedCount'] as num).toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: _date(json['completedAt']),
    progress: SessionProgress(
      total: (progress['total'] as num).toInt(),
      answered: (progress['answered'] as num).toInt(),
      flagged: (progress['flagged'] as num).toInt(),
      correct: (progress['correct'] as num?)?.toInt() ?? 0,
    ),
    questions: [
      for (final item in (json['questions'] as List? ?? const []))
        _questionFromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => a.order.compareTo(b.order)),
  );
}

StudySessionSummary studySessionSummaryFromJson(Map<String, dynamic> json) {
  return StudySessionSummary(
    id: json['id'] as String,
    status: studySessionStatusFromWire(json['status'] as String),
    feedbackMode: feedbackModeFromWire(json['feedbackMode'] as String),
    topicIds: (json['topicIds'] as List).cast<String>(),
    requestedCount: (json['requestedCount'] as num).toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: _date(json['completedAt']),
  );
}

SessionQuestion _questionFromJson(Map<String, dynamic> json) {
  final question = json['question'] as Map<String, dynamic>;
  final topic = question['topic'] as Map<String, dynamic>;
  return SessionQuestion(
    questionId: json['questionId'] as String,
    order: (json['order'] as num).toInt(),
    text: question['text'] as String,
    topic: SessionTopic(
      id: topic['id'] as String,
      name: topic['name'] as String,
    ),
    code: (question['code'] as num?)?.toInt(),
    losCode: question['losCode'] as String?,
    difficulty: question['difficulty'] as String?,
    explanation: question['explanation'] as String?,
    choices: [
      for (final choice in json['choices'] as List)
        SessionChoice(
          id: (choice as Map<String, dynamic>)['id'] as String,
          text: choice['text'] as String,
          isCorrect: choice['isCorrect'] as bool?,
        ),
    ],
    isFlagged: json['isFlagged'] as bool? ?? false,
    answeredAt: _date(json['answeredAt']),
    timeSpentSeconds: (json['timeSpentSeconds'] as num?)?.toInt() ?? 0,
    selectedChoiceId: json['selectedChoiceId'] as String?,
    isCorrect: json['isCorrect'] as bool?,
  );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

StudySessionStatus studySessionStatusFromWire(String value) => switch (value) {
  'PAUSED' => StudySessionStatus.paused,
  'COMPLETED' => StudySessionStatus.completed,
  _ => StudySessionStatus.inProgress,
};

FeedbackMode feedbackModeFromWire(String value) =>
    value == 'DEFERRED' ? FeedbackMode.atEnd : FeedbackMode.immediate;

String feedbackModeToWire(FeedbackMode mode) => switch (mode) {
  FeedbackMode.immediate => 'IMMEDIATE',
  FeedbackMode.atEnd => 'DEFERRED',
};
