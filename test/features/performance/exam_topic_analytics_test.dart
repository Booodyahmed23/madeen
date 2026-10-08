import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_analysis/data/datasources/ai_analysis_mock_data_source.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_review_item.dart';
import 'package:mobile/features/performance/data/datasources/performance_mock_data_source.dart';
import 'package:mobile/features/performance/data/mappers/exam_result_mapper.dart';
import 'package:mobile/features/performance/data/models/local_attempt_record.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';

import 'local_attempt_test_data.dart';

ExamReviewItem _q(String id, String topicId, String topicName, String? pick) =>
    ExamReviewItem(
      questionId: id,
      questionText: 'Q$id',
      choices: const [
        ExamAnswerChoice(id: 'a', text: 'A'),
        ExamAnswerChoice(id: 'b', text: 'B'),
      ],
      correctChoiceId: 'a',
      selectedChoiceId: pick,
      isCorrect: pick == 'a',
      wasFlagged: false,
      topicId: topicId,
      topicName: topicName,
    );

/// A simulation strong in Master Budget (4/4) and weak in Cost Behavior
/// (0 of 4: 2 wrong, 2 unanswered).
final _review = [
  for (var i = 0; i < 4; i++)
    _q('m$i', 'topic-master-budget', 'Master Budget', 'a'),
  _q('c0', 'topic-cost-behavior', 'Cost Behavior', 'b'),
  _q('c1', 'topic-cost-behavior', 'Cost Behavior', 'b'),
  _q('c2', 'topic-cost-behavior', 'Cost Behavior', null),
  _q('c3', 'topic-cost-behavior', 'Cost Behavior', null),
];

LocalAttemptRecord _examWithTopics() => localAttemptRecordFromExamResult(
  result: cmaPart2Result,
  config: cmaPart2Config,
  completedAt: DateTime(2026, 10, 7, 12),
  review: _review,
);

void main() {
  test('the exam mapper records one topic row per reviewed topic', () {
    final record = _examWithTopics();

    expect(record.topicId, isNull, reason: 'exams have no single topic');
    expect(record.topics.map((t) => t.topicId), [
      'topic-master-budget',
      'topic-cost-behavior',
    ]);
    final cost = record.topics.last;
    expect(cost.questionsAttempted, 4);
    expect(cost.answered, 2);
    expect(cost.correct, 0);
    expect(cost.wrong, 2);
    // The exam only times the attempt as a whole.
    expect(cost.averageTimePerQuestionSeconds, isNull);
    expect(record.toDetailsModel().topics, hasLength(2));
  });

  test('topic rows survive a JSON round trip (i.e. app restart)', () {
    final restored = LocalAttemptRecord.fromJson(_examWithTopics().toJson());
    expect(restored.topics.map((t) => (t.topicId, t.correct, t.wrong)), [
      ('topic-master-budget', 4, 0),
      ('topic-cost-behavior', 0, 2),
    ]);
  });

  test('records persisted before Phase 15 (no "topics" key) still load', () {
    final legacy = examRecord().toJson()..remove('topics');
    expect(LocalAttemptRecord.fromJson(legacy).topics, isEmpty);
  });

  group('Performance topic aggregation by attempt type', () {
    final source = PerformanceMockDataSource(
      localAttempts: [_examWithTopics()],
    );

    test('the Exam Simulation filter shows the exam\'s topics', () async {
      final topics = await source.getTopicPerformance(
        const PerformanceFilter(attemptType: AttemptTypeFilter.examSimulation),
      );
      expect(topics.map((t) => t.topicId), [
        'topic-master-budget',
        'topic-cost-behavior',
      ]);
    });

    test('the Study Session filter never includes exam topic rows', () async {
      final topics = await source.getTopicPerformance(
        const PerformanceFilter(attemptType: AttemptTypeFilter.studySession),
      );
      expect(
        topics.map((t) => t.topicId),
        isNot(contains('topic-master-budget')),
      );
      final cost = topics.firstWhere((t) => t.topicId == 'topic-cost-behavior');
      expect(cost.correct, 9, reason: 'fixture row only — no exam merge');
    });

    test('All merges exam rows into the same topics', () async {
      final topics = await source.getTopicPerformance(
        const PerformanceFilter(),
      );
      final cost = topics.firstWhere((t) => t.topicId == 'topic-cost-behavior');
      expect(cost.questionsAttempted, 15 + 4);
      expect(cost.wrong, 4 + 2);
    });
  });

  test('AI attempt analysis recognizes the simulation, its strong and weak '
      'topics, and its unanswered questions', () async {
    final record = _examWithTopics();
    final ai = AiAnalysisMockDataSource(
      PerformanceRepositoryImpl(
        PerformanceMockDataSource(localAttempts: [record]),
      ),
    );

    final model = await ai.getAttemptAnalysis(
      record.attemptId,
      languageCode: 'en',
    );

    expect(model.overallSummary, contains('Exam Simulation'));
    expect(model.strengths.single.text, contains('Master Budget'));
    expect(model.weaknesses.single.text, contains('Cost Behavior'));
    expect(model.topicInsights, hasLength(2));
    expect(
      model.recurringPatterns.map((p) => p.text),
      contains(contains('17 question(s) were left unanswered')),
    );
    expect(model.recommendations.first.topicId, 'topic-cost-behavior');
  });
}
