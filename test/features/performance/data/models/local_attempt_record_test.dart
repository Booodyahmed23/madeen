import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/data/models/local_attempt_record.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';

import '../../local_attempt_test_data.dart';

void main() {
  LocalAttemptRecord roundTrip(LocalAttemptRecord record) =>
      LocalAttemptRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );

  test('a Study Session record survives a JSON round trip, every field', () {
    final original = studyRecord(completedAt: DateTime(2026, 10, 4, 19, 6, 7));
    final copy = roundTrip(original);

    expect(copy.attemptId, original.attemptId);
    expect(copy.sourceId, 'mock-session-0');
    expect(copy.type, AttemptType.studySession);
    expect(copy.completedAt, original.completedAt);
    expect(copy.contentLabel, 'Variance Analysis');
    expect(copy.totalQuestions, 10);
    expect(copy.answered, 9);
    expect(copy.unanswered, 1);
    expect(copy.correct, 3);
    expect(copy.wrong, 6);
    expect(copy.scorePercent, 30);
    expect(copy.durationSeconds, 40);
    expect(copy.averageTimePerQuestionSeconds, 4);
    expect(copy.topicId, 'topic-variance-analysis');
    expect(copy.topicName, 'Variance Analysis');
  });

  test('an Exam record round-trips with a null topic', () {
    final copy = roundTrip(examRecord());

    expect(copy.type, AttemptType.examSimulation);
    expect(copy.topicId, isNull);
    expect(copy.topicName, isNull);
    expect(copy.toJson()['type'], 'EXAM');
  });

  test('records saved before the API (old type values) still load', () {
    final json = examRecord().toJson()..['type'] = 'EXAM_SIMULATION';

    expect(LocalAttemptRecord.fromJson(json).type, AttemptType.examSimulation);
  });

  test('rebuilds the Performance read models', () {
    final record = studyRecord();

    final summary = record.toSummaryModel().toEntity();
    expect(summary.attemptId, record.attemptId);
    expect(summary.duration, const Duration(seconds: 40));
    expect(summary.accuracyPercent, closeTo(33.3, 0.1));

    final details = record.toDetailsModel().toEntity();
    expect(details.unanswered, 1);
    expect(details.wrong, 6);
    expect(details.averageTimePerQuestion, const Duration(seconds: 4));
    expect(details.topics.single.topicId, 'topic-variance-analysis');

    final topic = record.toTopicModels().single;
    expect(topic.questionsAttempted, 10);
    expect(topic.answered, 9);
    expect(topic.correct, 3);
    expect(topic.wrong, 6);
  });

  test('an exam without a review breakdown has no topic rows', () {
    expect(examRecord().toTopicModels(), isEmpty);
    expect(examRecord().toDetailsModel().topics, isEmpty);
  });

  test('idFor is unique across launches even when mock ids repeat', () {
    final first = LocalAttemptRecord.idFor(
      'mock-session-0',
      DateTime(2026, 10, 4, 9),
    );
    final afterRestart = LocalAttemptRecord.idFor(
      'mock-session-0',
      DateTime(2026, 10, 4, 9, 0, 0, 0, 1),
    );

    expect(first, startsWith('local-mock-session-0-'));
    expect(first, isNot(afterRestart));
  });
}
