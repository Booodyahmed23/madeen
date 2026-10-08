import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/domain/entities/attempt_summary.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/entities/topic_performance.dart';

void main() {
  group('TopicPerformance', () {
    test('accuracyPercent = correct / answered * 100', () {
      const topic = TopicPerformance(
        topicId: 't1',
        topicName: 'Budgeting',
        questionsAttempted: 20,
        answered: 20,
        correct: 18,
        wrong: 2,
      );
      expect(topic.accuracyPercent, 90.0);
    });

    test('accuracyPercent is 0 (not NaN/Infinity) when answered is 0', () {
      const topic = TopicPerformance(
        topicId: 't1',
        topicName: 'Untouched',
        questionsAttempted: 5,
        answered: 0,
        correct: 0,
        wrong: 0,
      );
      expect(topic.accuracyPercent, 0);
    });

    test('isStrong is true at/above the strong threshold', () {
      const topic = TopicPerformance(
        topicId: 't1',
        topicName: 'Budgeting',
        questionsAttempted: 20,
        answered: 20,
        correct: 16,
        wrong: 4,
      );
      expect(topic.accuracyPercent, 80.0);
      expect(topic.isStrong, isTrue);
      expect(topic.needsPractice, isFalse);
    });

    test('needsPractice is true below the needs-practice threshold', () {
      const topic = TopicPerformance(
        topicId: 't1',
        topicName: 'Variance Analysis',
        questionsAttempted: 20,
        answered: 20,
        correct: 11,
        wrong: 9,
      );
      expect(topic.accuracyPercent, closeTo(55.0, 0.001));
      expect(topic.needsPractice, isTrue);
      expect(topic.isStrong, isFalse);
    });

    test('a topic between the thresholds is neither strong nor needing '
        'practice', () {
      const topic = TopicPerformance(
        topicId: 't1',
        topicName: 'Financial Statements',
        questionsAttempted: 20,
        answered: 20,
        correct: 15,
        wrong: 5,
      );
      expect(topic.accuracyPercent, 75.0);
      expect(topic.isStrong, isFalse);
      expect(topic.needsPractice, isFalse);
    });

    test('a never-answered topic is neither strong nor needing practice', () {
      const topic = TopicPerformance(
        topicId: 't1',
        topicName: 'Untouched',
        questionsAttempted: 5,
        answered: 0,
        correct: 0,
        wrong: 0,
      );
      expect(topic.isStrong, isFalse);
      expect(topic.needsPractice, isFalse);
    });
  });

  group('AttemptSummary', () {
    test('scorePercent and accuracyPercent can legitimately differ', () {
      final attempt = AttemptSummary(
        attemptId: 'a1',
        type: AttemptType.examSimulation,
        completedAt: DateTime(2026, 9, 15),
        contentLabel: 'CMA Part 1',
        totalQuestions: 80,
        answered: 74,
        correct: 58,
        scorePercent: 72.5,
        duration: const Duration(hours: 3, minutes: 20),
      );
      expect(attempt.scorePercent, 72.5);
      expect(attempt.accuracyPercent, closeTo(78.378, 0.001));
      expect(attempt.accuracyPercent, isNot(attempt.scorePercent));
    });

    test('accuracyPercent guards zero-answered without dividing by zero', () {
      final attempt = AttemptSummary(
        attemptId: 'a1',
        type: AttemptType.studySession,
        completedAt: DateTime(2026, 9, 15),
        contentLabel: 'Budgeting',
        totalQuestions: 20,
        answered: 0,
        correct: 0,
        scorePercent: 0,
        duration: Duration.zero,
      );
      expect(attempt.accuracyPercent, 0);
    });
  });

  group('PerformanceOverview', () {
    test('overallAccuracyPercent = totalCorrect / totalAnswered * 100', () {
      const overview = PerformanceOverview(
        totalAttempts: 6,
        questionsPracticed: 205,
        totalAnswered: 197,
        totalCorrect: 151,
        overallScorePercent: 73.66,
        totalTime: Duration(seconds: 25000),
        averageTimePerQuestion: Duration(seconds: 121),
      );
      expect(overview.overallAccuracyPercent, closeTo(76.65, 0.01));
    });

    test('overallAccuracyPercent is 0 for a student with no attempts', () {
      const overview = PerformanceOverview(
        totalAttempts: 0,
        questionsPracticed: 0,
        totalAnswered: 0,
        totalCorrect: 0,
        overallScorePercent: 0,
        totalTime: Duration.zero,
        averageTimePerQuestion: Duration.zero,
      );
      expect(overview.overallAccuracyPercent, 0);
    });
  });

  group('PerformanceFilter', () {
    test('copyWith only overrides the given fields', () {
      const filter = PerformanceFilter();
      final updated = filter.copyWith(
        attemptType: AttemptTypeFilter.studySession,
      );
      expect(updated.attemptType, AttemptTypeFilter.studySession);
      expect(updated.topicFilter, TopicPerformanceFilter.all);
    });

    test('equal field values compare equal (family-key friendly)', () {
      const a = PerformanceFilter(
        attemptType: AttemptTypeFilter.examSimulation,
      );
      const b = PerformanceFilter(
        attemptType: AttemptTypeFilter.examSimulation,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('AttemptType wire mapping', () {
    test('round-trips through toWire/fromWire', () {
      for (final type in AttemptType.values) {
        expect(AttemptType.fromWire(type.toWire()), type);
      }
    });

    test('fromWire throws on an unknown value', () {
      expect(
        () => AttemptType.fromWire('SOMETHING_ELSE'),
        throwsFormatException,
      );
    });
  });
}
