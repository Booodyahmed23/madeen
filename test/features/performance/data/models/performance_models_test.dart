import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/data/models/attempt_details_model.dart';
import 'package:mobile/features/performance/data/models/attempt_history_page_model.dart';
import 'package:mobile/features/performance/data/models/attempt_summary_model.dart';
import 'package:mobile/features/performance/data/models/performance_overview_model.dart';
import 'package:mobile/features/performance/data/models/topic_performance_model.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';

void main() {
  group('TopicPerformanceModel', () {
    test('fromJson/toEntity round trip, including averageTimePerQuestion', () {
      final model = TopicPerformanceModel.fromJson({
        'topicId': 'topic-budgeting',
        'topicName': 'Budgeting',
        'questionsAttempted': 20,
        'answered': 20,
        'correct': 18,
        'wrong': 2,
        'averageTimePerQuestionSeconds': 60,
      });
      final entity = model.toEntity();
      expect(entity.topicId, 'topic-budgeting');
      expect(entity.accuracyPercent, 90.0);
      expect(entity.averageTimePerQuestion, const Duration(seconds: 60));
    });

    test('a missing averageTimePerQuestionSeconds maps to null, not zero', () {
      final model = TopicPerformanceModel.fromJson({
        'topicId': 't1',
        'topicName': 'Cost Behavior',
        'questionsAttempted': 5,
        'answered': 5,
        'correct': 3,
        'wrong': 2,
      });
      expect(model.toEntity().averageTimePerQuestion, isNull);
    });
  });

  group('AttemptSummaryModel', () {
    test('fromJson/toEntity round trip', () {
      final model = AttemptSummaryModel.fromJson({
        'attemptId': 'attempt-1',
        'type': 'STUDY_SESSION',
        'completedAt': '2026-09-16T09:00:00.000Z',
        'contentLabel': 'Budgeting',
        'totalQuestions': 20,
        'answered': 20,
        'correct': 18,
        'scorePercent': 90.0,
        'durationSeconds': 1200,
      });
      final entity = model.toEntity();
      expect(entity.type, AttemptType.studySession);
      expect(entity.duration, const Duration(seconds: 1200));
      expect(entity.accuracyPercent, 90.0);
    });

    test('an unknown type value throws rather than silently defaulting', () {
      expect(
        () => AttemptSummaryModel.fromJson({
          'attemptId': 'attempt-1',
          'type': 'BOGUS',
          'completedAt': '2026-09-16T09:00:00.000Z',
          'contentLabel': 'Budgeting',
          'totalQuestions': 20,
          'answered': 20,
          'correct': 18,
          'scorePercent': 90.0,
          'durationSeconds': 1200,
        }),
        throwsFormatException,
      );
    });
  });

  group('AttemptDetailsModel', () {
    test('parses the flattened summary fields plus detail-only fields', () {
      final model = AttemptDetailsModel.fromJson({
        'attemptId': 'attempt-2',
        'type': 'EXAM_SIMULATION',
        'completedAt': '2026-09-15T14:00:00.000Z',
        'contentLabel': 'CMA Part 1',
        'totalQuestions': 80,
        'answered': 74,
        'correct': 58,
        'scorePercent': 72.5,
        'durationSeconds': 12000,
        'unanswered': 6,
        'wrong': 16,
        'averageTimePerQuestionSeconds': 150,
        // Exam attempts carry no topic breakdown.
        'topics': <Map<String, dynamic>>[],
      });
      final entity = model.toEntity();
      expect(entity.summary.attemptId, 'attempt-2');
      expect(entity.unanswered, 6);
      expect(entity.topics, isEmpty);
    });

    test('a missing "topics" key maps to an empty list, not null/crash', () {
      final model = AttemptDetailsModel.fromJson({
        'attemptId': 'attempt-1',
        'type': 'STUDY_SESSION',
        'completedAt': '2026-09-16T09:00:00.000Z',
        'contentLabel': 'Budgeting',
        'totalQuestions': 20,
        'answered': 20,
        'correct': 18,
        'scorePercent': 90.0,
        'durationSeconds': 1200,
        'unanswered': 0,
        'wrong': 2,
        'averageTimePerQuestionSeconds': 60,
      });
      expect(model.toEntity().topics, isEmpty);
    });
  });

  group('PerformanceOverviewModel', () {
    test('fromJson/toEntity round trip', () {
      final model = PerformanceOverviewModel.fromJson({
        'totalAttempts': 6,
        'questionsPracticed': 205,
        'totalAnswered': 197,
        'totalCorrect': 151,
        'overallScorePercent': 73.66,
        'totalTimeSeconds': 25000,
        'averageTimePerQuestionSeconds': 121,
      });
      final entity = model.toEntity();
      expect(entity.totalTime, const Duration(seconds: 25000));
      expect(entity.overallAccuracyPercent, closeTo(76.65, 0.01));
    });
  });

  group('AttemptHistoryPageModel', () {
    test('fromJson/toEntity round trip, preserving hasMore', () {
      final model = AttemptHistoryPageModel.fromJson({
        'items': [
          {
            'attemptId': 'attempt-1',
            'type': 'STUDY_SESSION',
            'completedAt': '2026-09-16T09:00:00.000Z',
            'contentLabel': 'Budgeting',
            'totalQuestions': 20,
            'answered': 20,
            'correct': 18,
            'scorePercent': 90.0,
            'durationSeconds': 1200,
          },
        ],
        'hasMore': true,
      });
      final entity = model.toEntity();
      expect(entity.items, hasLength(1));
      expect(entity.hasMore, isTrue);
    });
  });
}
