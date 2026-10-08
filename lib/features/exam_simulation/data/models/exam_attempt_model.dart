import '../../domain/entities/exam_attempt.dart';

/// JSON → domain for the API's exam Attempt object and list rows
/// (contract §A4). The only place that knows these key names and the
/// UPPER_SNAKE status values (§G6).
ExamAttempt examAttemptFromJson(Map<String, dynamic> json) {
  final progress = json['progress'] as Map<String, dynamic>;
  final score = json['score'] as Map<String, dynamic>?;
  return ExamAttempt(
    id: json['id'] as String,
    status: examAttemptStatusFromWire(json['status'] as String),
    durationMinutes: (json['durationMinutes'] as num).toInt(),
    topicIds: (json['topicIds'] as List).cast<String>(),
    requestedCount: (json['requestedCount'] as num).toInt(),
    startedAt: DateTime.parse(json['startedAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    submittedAt: _date(json['submittedAt']),
    remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
    progress: ExamProgress(
      total: (progress['total'] as num).toInt(),
      answered: (progress['answered'] as num).toInt(),
      flagged: (progress['flagged'] as num).toInt(),
    ),
    score: score == null
        ? null
        : ExamScore(
            correct: (score['correct'] as num).toInt(),
            incorrect: (score['incorrect'] as num).toInt(),
            unanswered: (score['unanswered'] as num).toInt(),
          ),
    questions: [
      for (final item in (json['questions'] as List? ?? const []))
        _questionFromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => a.order.compareTo(b.order)),
  );
}

ExamAttemptSummary examAttemptSummaryFromJson(Map<String, dynamic> json) {
  return ExamAttemptSummary(
    id: json['id'] as String,
    status: examAttemptStatusFromWire(json['status'] as String),
    durationMinutes: (json['durationMinutes'] as num).toInt(),
    topicIds: (json['topicIds'] as List).cast<String>(),
    requestedCount: (json['requestedCount'] as num).toInt(),
    startedAt: DateTime.parse(json['startedAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    submittedAt: _date(json['submittedAt']),
  );
}

ExamAttemptQuestion _questionFromJson(Map<String, dynamic> json) {
  final question = json['question'] as Map<String, dynamic>;
  final topic = question['topic'] as Map<String, dynamic>;
  return ExamAttemptQuestion(
    questionId: json['questionId'] as String,
    order: (json['order'] as num).toInt(),
    text: question['text'] as String,
    topicId: topic['id'] as String,
    topicName: topic['name'] as String,
    explanation: question['explanation'] as String?,
    choices: [
      for (final choice in json['choices'] as List)
        ExamAttemptChoice(
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

ExamAttemptStatus examAttemptStatusFromWire(String value) => switch (value) {
  'SUBMITTED' => ExamAttemptStatus.submitted,
  'EXPIRED' => ExamAttemptStatus.expired,
  _ => ExamAttemptStatus.inProgress,
};
