import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/performance/data/datasources/performance_mock_data_source.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';

void main() {
  late PerformanceMockDataSource dataSource;

  setUp(() {
    dataSource = PerformanceMockDataSource();
  });

  group('internal consistency', () {
    test(
      'every attempt returned by getAttempts satisfies '
      'answered = correct + wrong and unanswered + answered = total',
      () async {
        final page = await dataSource.getAttempts(
          const PerformanceFilter(),
          limit: 100,
          offset: 0,
        );
        expect(page.items, isNotEmpty);
        for (final attempt in page.items) {
          final details = await dataSource.getAttemptDetails(attempt.attemptId);
          expect(
            attempt.answered,
            attempt.correct + details.wrong,
            reason:
                'answered should equal correct + wrong for '
                '${attempt.attemptId}',
          );
          expect(
            attempt.totalQuestions,
            attempt.answered + details.unanswered,
            reason:
                'total should equal answered + unanswered for '
                '${attempt.attemptId}',
          );
        }
      },
    );

    test(
      'overview totals equal the sum across every attempt (no filter)',
      () async {
        final overview = await dataSource.getOverview(
          const PerformanceFilter(),
        );
        final page = await dataSource.getAttempts(
          const PerformanceFilter(),
          limit: 100,
          offset: 0,
        );

        final expectedQuestions = page.items.fold(
          0,
          (sum, a) => sum + a.totalQuestions,
        );
        final expectedAnswered = page.items.fold(
          0,
          (sum, a) => sum + a.answered,
        );
        final expectedCorrect = page.items.fold(0, (sum, a) => sum + a.correct);

        expect(overview.totalAttempts, page.items.length);
        expect(overview.questionsPracticed, expectedQuestions);
        expect(overview.totalAnswered, expectedAnswered);
        expect(overview.totalCorrect, expectedCorrect);
      },
    );

    test('topic performance rows are only ever answered<=attempted', () async {
      final topics = await dataSource.getTopicPerformance(
        const PerformanceFilter(),
      );
      expect(topics, isNotEmpty);
      for (final topic in topics) {
        expect(topic.answered, lessThanOrEqualTo(topic.questionsAttempted));
        expect(topic.correct + topic.wrong, topic.answered);
      }
    });
  });

  group('filtering by attemptType', () {
    test('studySession filter returns only Study Session attempts', () async {
      final page = await dataSource.getAttempts(
        const PerformanceFilter(attemptType: AttemptTypeFilter.studySession),
        limit: 100,
        offset: 0,
      );
      expect(page.items, isNotEmpty);
      expect(
        page.items.every((a) => a.type == AttemptType.studySession),
        isTrue,
      );
    });

    test(
      'examSimulation filter returns only Exam Simulation attempts',
      () async {
        final page = await dataSource.getAttempts(
          const PerformanceFilter(
            attemptType: AttemptTypeFilter.examSimulation,
          ),
          limit: 100,
          offset: 0,
        );
        expect(page.items, isNotEmpty);
        expect(
          page.items.every((a) => a.type == AttemptType.examSimulation),
          isTrue,
        );
      },
    );

    test('Exam Simulation never contributes topic performance rows', () async {
      final topics = await dataSource.getTopicPerformance(
        const PerformanceFilter(attemptType: AttemptTypeFilter.examSimulation),
      );
      expect(topics, isEmpty);
    });
  });

  group('pagination', () {
    test(
      'hasMore is true when more items remain, false on the last page',
      () async {
        final firstPage = await dataSource.getAttempts(
          const PerformanceFilter(),
          limit: 2,
          offset: 0,
        );
        expect(firstPage.items, hasLength(2));
        expect(firstPage.hasMore, isTrue);

        final allItems = await dataSource.getAttempts(
          const PerformanceFilter(),
          limit: 100,
          offset: 0,
        );
        final total = allItems.items.length;

        final lastPage = await dataSource.getAttempts(
          const PerformanceFilter(),
          limit: 100,
          offset: total - 1,
        );
        expect(lastPage.items, hasLength(1));
        expect(lastPage.hasMore, isFalse);
      },
    );

    test(
      'an offset past the end returns an empty page, not an error',
      () async {
        final page = await dataSource.getAttempts(
          const PerformanceFilter(),
          limit: 10,
          offset: 9999,
        );
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      },
    );
  });

  group('getAttemptDetails', () {
    test('an unknown attemptId throws rather than returning bad data', () {
      expect(
        () => dataSource.getAttemptDetails('does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });

    test('a Study Session attempt has a non-empty topic breakdown', () async {
      final details = await dataSource.getAttemptDetails('perf-attempt-1');
      expect(details.summary.attemptId, 'perf-attempt-1');
      expect(details.topics, isNotEmpty);
    });

    test('an Exam Simulation attempt has no topic breakdown', () async {
      final details = await dataSource.getAttemptDetails('perf-attempt-2');
      expect(details.topics, isEmpty);
    });
  });
}
