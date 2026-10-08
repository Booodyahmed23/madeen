import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/data/datasources/performance_mock_data_source.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';

import '../../local_attempt_test_data.dart';

const _all = PerformanceFilter();
const _studyOnly = PerformanceFilter(
  attemptType: AttemptTypeFilter.studySession,
);
const _examOnly = PerformanceFilter(
  attemptType: AttemptTypeFilter.examSimulation,
);

void main() {
  group('zero local attempts preserves every fixture number', () {
    final plain = PerformanceMockDataSource();
    final empty = PerformanceMockDataSource(localAttempts: const []);

    test('overview', () async {
      final overview = await empty.getOverview(_all);
      expect(overview.totalAttempts, 6);
      expect(overview.questionsPracticed, 205);
      expect(overview.totalAnswered, 197);
      expect(overview.totalCorrect, 151);
      expect(overview.totalTimeSeconds, 25000);
      expect(
        overview.overallScorePercent,
        (await plain.getOverview(_all)).overallScorePercent,
      );
    });

    test('topics, history and details', () async {
      final topics = await empty.getTopicPerformance(_all);
      expect(topics.map((t) => t.topicId), [
        'topic-budgeting',
        'topic-financial-statements',
        'topic-variance-analysis',
        'topic-cost-behavior',
      ]);
      final page = await empty.getAttempts(_all, limit: 20, offset: 0);
      expect(page.items.map((a) => a.attemptId), [
        for (var i = 1; i <= 6; i++) 'perf-attempt-$i',
      ]);
      expect(
        (await empty.getAttemptDetails('perf-attempt-1')).topics.single.topicId,
        'topic-budgeting',
      );
    });
  });

  group('with local attempts', () {
    final dataSource = PerformanceMockDataSource(
      localAttempts: [examRecord(), studyRecord()],
    );

    test('overview adds the local attempts to the fixture totals', () async {
      final overview = await dataSource.getOverview(_all);

      expect(overview.totalAttempts, 8);
      expect(overview.questionsPracticed, 205 + 10 + 25);
      expect(overview.totalAnswered, 197 + 9 + 8);
      expect(overview.totalCorrect, 151 + 3 + 2);
      // The same 73% / 65% verified live on the simulator.
      expect(
        (overview.totalCorrect / overview.totalAnswered * 100).round(),
        73,
      );
      expect(overview.overallScorePercent.round(), 65);
    });

    test(
      'history is newest first, local attempts ahead of older fixtures',
      () async {
        final page = await dataSource.getAttempts(_all, limit: 3, offset: 0);

        expect(page.items.map((a) => a.attemptId), [
          'local-e-1',
          'local-s-1',
          'perf-attempt-1',
        ]);
        expect(page.hasMore, isTrue);
      },
    );

    test('pagination walks the merged list without gaps or repeats', () async {
      final ids = <String>[];
      var offset = 0;
      while (true) {
        final page = await dataSource.getAttempts(
          _all,
          limit: 3,
          offset: offset,
        );
        ids.addAll(page.items.map((a) => a.attemptId));
        offset += page.items.length;
        if (!page.hasMore) break;
      }

      expect(ids, hasLength(8));
      expect(ids.toSet(), hasLength(8));
    });

    test('a local attempt id resolves to full details', () async {
      final details = await dataSource.getAttemptDetails('local-s-1');

      expect(details.summary.type, AttemptType.studySession);
      expect(details.unanswered, 1);
      expect(details.wrong, 6);
      expect(details.averageTimePerQuestionSeconds, 4);
      expect(details.topics.single.topicId, 'topic-variance-analysis');

      final exam = await dataSource.getAttemptDetails('local-e-1');
      expect(exam.topics, isEmpty);
    });

    test('exam-only filter includes the local exam and no topics', () async {
      final page = await dataSource.getAttempts(
        _examOnly,
        limit: 20,
        offset: 0,
      );
      expect(
        page.items.map((a) => a.type),
        everyElement(AttemptType.examSimulation),
      );
      expect(page.items.first.attemptId, 'local-e-1');
      expect(await dataSource.getTopicPerformance(_examOnly), isEmpty);
    });

    test('study-only filter excludes the local exam', () async {
      final overview = await dataSource.getOverview(_studyOnly);
      expect(overview.totalAttempts, 4 + 1);
    });
  });

  group('topic aggregation', () {
    test('an overlapping topic is ONE row with summed counts and a weighted '
        'average time', () async {
      final dataSource = PerformanceMockDataSource(
        localAttempts: [studyRecord()],
      );

      final topics = await dataSource.getTopicPerformance(_all);
      final variance = topics.where(
        (t) => t.topicId == 'topic-variance-analysis',
      );

      expect(variance, hasLength(1));
      final row = variance.single;
      // Fixture 20 attempted / 20 answered / 11 correct / 9 wrong @ 90s,
      // plus local 10 / 9 / 3 / 6 @ 4s.
      expect(row.questionsAttempted, 30);
      expect(row.answered, 29);
      expect(row.correct, 14);
      expect(row.wrong, 15);
      expect(
        row.averageTimePerQuestionSeconds,
        ((90 * 20 + 4 * 9) / 29).round(),
      );
      expect(topics, hasLength(4), reason: 'no duplicate rows');
    });

    test(
      'several local attempts on the same new topic aggregate too',
      () async {
        final dataSource = PerformanceMockDataSource(
          localAttempts: [
            studyRecord(
              id: 'm1',
              topicId: 'topic-master-budget',
              topicName: 'Master Budget',
              total: 10,
              answered: 10,
              correct: 9,
              avgSeconds: 30,
            ),
            studyRecord(
              id: 'm2',
              topicId: 'topic-master-budget',
              topicName: 'Master Budget',
              total: 20,
              answered: 20,
              correct: 10,
              avgSeconds: 60,
            ),
          ],
        );

        final topics = await dataSource.getTopicPerformance(_all);

        expect(topics, hasLength(5));
        final master = topics.last;
        expect(master.topicId, 'topic-master-budget');
        expect(master.answered, 30);
        expect(master.correct, 19);
        expect(master.averageTimePerQuestionSeconds, 50);
      },
    );

    test('exam records never create topic rows', () async {
      final dataSource = PerformanceMockDataSource(
        localAttempts: [examRecord()],
      );

      expect(await dataSource.getTopicPerformance(_all), hasLength(4));
    });
  });
}
