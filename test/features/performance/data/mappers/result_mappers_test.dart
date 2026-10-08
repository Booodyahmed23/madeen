import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/data/models/local_attempt_record.dart';

import '../../local_attempt_test_data.dart';

import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_result.dart';
import 'package:mobile/features/performance/data/mappers/exam_result_mapper.dart';
import 'package:mobile/features/performance/data/mappers/session_result_mapper.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/session_result.dart';

void main() {
  group('attemptSummaryFromSessionResult', () {
    test('maps every field, tagging the attempt as a Study Session', () {
      const config = SessionConfig(
        topicId: 'topic-budgeting',
        topicName: 'Budgeting',
        questionCount: 20,
        feedbackMode: FeedbackMode.immediate,
      );
      const result = SessionResult(
        sessionId: 'sess-1',
        totalQuestions: 20,
        answered: 20,
        unanswered: 0,
        correct: 18,
        incorrect: 2,
        scorePercent: 90.0,
        totalTime: Duration(seconds: 1200),
        averageTimePerQuestion: Duration(seconds: 60),
      );
      final completedAt = DateTime(2026, 9, 16, 9);

      final summary = attemptSummaryFromSessionResult(
        result: result,
        config: config,
        completedAt: completedAt,
      );

      expect(summary.attemptId, 'sess-1');
      expect(summary.type, AttemptType.studySession);
      expect(summary.contentLabel, 'Budgeting');
      expect(summary.completedAt, completedAt);
      expect(summary.totalQuestions, 20);
      expect(summary.correct, 18);
      expect(summary.scorePercent, 90.0);
      expect(summary.duration, const Duration(seconds: 1200));
    });
  });

  group('attemptSummaryFromExamResult', () {
    test('maps every field, tagging the attempt as an Exam Simulation and '
        'combining program + part into contentLabel', () {
      const config = ExamConfig(
        programId: 'program-cma',
        programName: 'CMA',
        partId: 'cma-part-1',
        partName: 'Part 1',
        questionCount: 80,
        duration: Duration(hours: 4),
        topicIds: ['topic-1'],
      );
      const result = ExamResult(
        attemptId: 'attempt-1',
        totalQuestions: 80,
        answered: 74,
        unanswered: 6,
        correct: 58,
        incorrect: 16,
        scorePercent: 72.5,
        durationTaken: Duration(hours: 3, minutes: 20),
        completionStatus: 'completed',
      );
      final completedAt = DateTime(2026, 9, 15, 14);

      final summary = attemptSummaryFromExamResult(
        result: result,
        config: config,
        completedAt: completedAt,
      );

      expect(summary.attemptId, 'attempt-1');
      expect(summary.type, AttemptType.examSimulation);
      expect(summary.contentLabel, 'CMA Part 1');
      expect(summary.answered, 74);
      expect(summary.correct, 58);
      expect(summary.scorePercent, 72.5);
      expect(summary.duration, const Duration(hours: 3, minutes: 20));
    });
  });

  group('localAttemptRecordFromSessionResult', () {
    test('maps every field and keeps the Study Session topic', () {
      final completedAt = DateTime(2026, 10, 4, 19, 6);
      final record = localAttemptRecordFromSessionResult(
        result: varianceResult,
        config: varianceConfig,
        completedAt: completedAt,
      );

      expect(
        record.attemptId,
        LocalAttemptRecord.idFor('mock-session-0', completedAt),
      );
      expect(record.sourceId, 'mock-session-0');
      expect(record.type, AttemptType.studySession);
      expect(record.completedAt, completedAt);
      expect(record.contentLabel, 'Variance Analysis');
      expect(record.totalQuestions, 10);
      expect(record.answered, 9);
      expect(record.unanswered, 1);
      expect(record.correct, 3);
      expect(record.wrong, 6);
      expect(record.scorePercent, 30);
      expect(record.durationSeconds, 45);
      expect(record.averageTimePerQuestionSeconds, 4);
      expect(record.topicId, 'topic-variance-analysis');
      expect(record.topicName, 'Variance Analysis');
    });

    test('agrees with the existing summary mapper (one mapping, not two)', () {
      final completedAt = DateTime(2026, 10, 4);
      final summary = attemptSummaryFromSessionResult(
        result: varianceResult,
        config: varianceConfig,
        completedAt: completedAt,
      );
      final record = localAttemptRecordFromSessionResult(
        result: varianceResult,
        config: varianceConfig,
        completedAt: completedAt,
      ).toSummaryModel().toEntity();

      expect(record.contentLabel, summary.contentLabel);
      expect(record.scorePercent, summary.scorePercent);
      expect(record.duration, summary.duration);
    });
  });

  group('localAttemptRecordFromExamResult', () {
    test('maps every field, with no topic', () {
      final completedAt = DateTime(2026, 10, 4, 19, 9);
      final record = localAttemptRecordFromExamResult(
        result: cmaPart2Result,
        config: cmaPart2Config,
        completedAt: completedAt,
      );

      expect(record.type, AttemptType.examSimulation);
      expect(record.contentLabel, 'CMA Part 2');
      expect(record.answered, 8);
      expect(record.unanswered, 17);
      expect(record.correct, 2);
      expect(record.wrong, 6);
      expect(record.durationSeconds, 41);
      expect(record.averageTimePerQuestionSeconds, 41 ~/ 25);
      expect(record.topicId, isNull);
      expect(record.topicName, isNull);
    });
  });

  test('the same mock id completed in two launches gets two distinct ids', () {
    final first = localAttemptRecordFromSessionResult(
      result: varianceResult,
      config: varianceConfig,
      completedAt: DateTime(2026, 10, 4, 9),
    );
    final second = localAttemptRecordFromSessionResult(
      result: varianceResult,
      config: varianceConfig,
      completedAt: DateTime(2026, 10, 5, 9),
    );

    expect(first.sourceId, second.sourceId);
    expect(first.attemptId, isNot(second.attemptId));
  });
}
