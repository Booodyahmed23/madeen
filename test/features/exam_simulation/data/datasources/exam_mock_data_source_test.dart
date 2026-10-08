import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/exam_simulation/data/datasources/exam_mock_data_source.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';

void main() {
  late ExamMockDataSource dataSource;

  setUp(() => dataSource = ExamMockDataSource());

  const config = ExamConfig(
    programId: 'program-cma',
    programName: 'CMA',
    partId: 'cma-part-1',
    partName: 'Part 1',
    questionCount: 10,
    duration: Duration(hours: 1),
  );

  test(
    'startExam returns exactly questionCount questions, each with 4 choices',
    () async {
      final attempt = await dataSource.startExam(config);

      expect(attempt.questions, hasLength(10));
      for (final question in attempt.questions) {
        expect(question.choices, hasLength(4));
      }
    },
  );

  test(
    'startExam echoes the requested duration as the authoritative duration',
    () async {
      final attempt = await dataSource.startExam(config);
      expect(attempt.durationSeconds, config.duration.inSeconds);
    },
  );

  test(
    'no question text or content ever mentions a topic/program/part',
    () async {
      final attempt = await dataSource.startExam(config);
      for (final question in attempt.questions) {
        expect(question.text.toLowerCase(), isNot(contains('cma')));
        expect(question.text.toLowerCase(), isNot(contains('part 1')));
      }
    },
  );

  test('getAttempt reloads a started attempt by id', () async {
    final started = await dataSource.startExam(config);
    final reloaded = await dataSource.getAttempt(started.attemptId);

    expect(reloaded.attemptId, started.attemptId);
    expect(reloaded.questions.length, started.questions.length);
  });

  test(
    'getAttempt on an unknown id throws rather than returning nonsense',
    () async {
      expect(
        () => dataSource.getAttempt('unknown'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('submitExam and getReview agree on which choice is correct, and reflect flags', () async {
    final attempt = await dataSource.startExam(config);
    final firstQuestion = attempt.questions.first;

    // Discover the correct choice for the first question by trying each
    // one via submitExam and checking which produces a perfect score.
    String? correctChoiceId;
    for (final choice in firstQuestion.choices) {
      final result = await dataSource.submitExam(
        attemptId: attempt.attemptId,
        answers: {firstQuestion.id: choice.id},
        flaggedQuestionIds: const {},
        timeTaken: const Duration(minutes: 1),
      );
      if (result.correct == 1) {
        correctChoiceId = choice.id;
        break;
      }
    }
    expect(correctChoiceId, isNotNull);

    // Submit every question with its first choice — this test only
    // needs internal consistency between submitExam's aggregate score
    // and getReview's per-item correctness, not a 100% score.
    final answers = <String, String?>{
      for (final question in attempt.questions)
        question.id: question.choices.first.id,
    };
    final flaggedId = attempt.questions[1].id;
    final result = await dataSource.submitExam(
      attemptId: attempt.attemptId,
      answers: answers,
      flaggedQuestionIds: {flaggedId},
      timeTaken: const Duration(minutes: 30),
    );

    final review = await dataSource.getReview(attempt.attemptId);
    expect(review, hasLength(attempt.questions.length));

    final correctFromReview = review.where((r) => r.isCorrect).length;
    expect(correctFromReview, result.correct);

    final flaggedReviewItem = review.firstWhere(
      (r) => r.questionId == flaggedId,
    );
    expect(flaggedReviewItem.wasFlagged, isTrue);
    final notFlagged = review.firstWhere((r) => r.questionId != flaggedId);
    expect(notFlagged.wasFlagged, isFalse);
  });

  test('submitExam correctly tallies unanswered questions', () async {
    final attempt = await dataSource.startExam(config);
    final answers = <String, String?>{
      for (final q in attempt.questions) q.id: null,
    };

    final result = await dataSource.submitExam(
      attemptId: attempt.attemptId,
      answers: answers,
      flaggedQuestionIds: const {},
      timeTaken: const Duration(minutes: 5),
    );

    expect(result.answered, 0);
    expect(result.unanswered, attempt.questions.length);
    expect(result.correct, 0);
    expect(result.scorePercent, 0.0);
    expect(result.completionStatus, 'completed');
  });

  test('getReview on an unknown attempt returns an empty list rather than throwing', () async {
    final review = await dataSource.getReview('unknown-attempt');
    expect(review, isEmpty);
  });

  group('Phase 15: scope, order, topics, timeout', () {
    ExamConfig scoped({
      String? unitId,
      String? unitName,
      String? subUnitId,
      String? subUnitName,
      String partId = 'cma-part-1',
      ExamQuestionOrder order = ExamQuestionOrder.original,
      int count = 8,
    }) => ExamConfig(
      programId: 'program-cma',
      programName: 'CMA',
      partId: partId,
      partName: 'Part 1',
      unitId: unitId,
      unitName: unitName,
      subUnitId: subUnitId,
      subUnitName: subUnitName,
      questionCount: count,
      duration: const Duration(minutes: 15),
      questionOrder: order,
    );

    Future<List<String?>> reviewTopics(ExamConfig config) async {
      final attempt = await dataSource.startExam(config);
      await dataSource.submitExam(
        attemptId: attempt.attemptId,
        answers: const {},
        flaggedQuestionIds: const {},
        timeTaken: const Duration(seconds: 10),
      );
      final review = await dataSource.getReview(attempt.attemptId);
      return [for (final item in review) item.topicId];
    }

    test('a sub-unit scope draws only that sub-unit\'s topics', () async {
      final topics = await reviewTopics(
        scoped(
          unitId: 'unit-financial-planning',
          subUnitId: 'subunit-budgeting',
          subUnitName: 'Budgeting',
        ),
      );
      expect(topics.toSet(), {
        'topic-flexible-budget',
        'topic-master-budget',
        'topic-variance-analysis',
      });
    });

    test('a whole-Part scope spreads questions across its topics', () async {
      final topics = await reviewTopics(scoped());
      expect(topics.toSet(), hasLength(4));
      expect(topics, contains('topic-cost-behavior'));
    });

    test(
      'a scope with no sample topics groups under that scope node',
      () async {
        final topics = await reviewTopics(
          scoped(
            unitId: 'unit-internal-controls',
            unitName: 'Internal Controls',
          ),
        );
        expect(topics.toSet(), {'unit-internal-controls'});
      },
    );

    test('topics never appear on the in-exam questions', () async {
      final attempt = await dataSource.startExam(scoped());
      for (final question in attempt.questions) {
        expect(question.toEntity().text, isNot(contains('Budget')));
      }
    });

    test('random order shuffles; original order keeps sequence', () async {
      final original = await dataSource.startExam(scoped(count: 20));
      expect(original.questions.map((q) => q.id), [
        for (var i = 0; i < 20; i++) 'mock-exam-q-cma-part-1-$i',
      ]);

      final seeded = ExamMockDataSource(random: Random(7));
      final random = await seeded.startExam(
        scoped(count: 20, order: ExamQuestionOrder.random),
      );
      final ids = random.questions.map((q) => q.id).toList();
      expect(ids.toSet(), original.questions.map((q) => q.id).toSet());
      expect(ids, isNot(original.questions.map((q) => q.id).toList()));
    });

    test('using the whole countdown reports timed_out', () async {
      final attempt = await dataSource.startExam(scoped());
      final result = await dataSource.submitExam(
        attemptId: attempt.attemptId,
        answers: const {},
        flaggedQuestionIds: const {},
        timeTaken: Duration(seconds: attempt.durationSeconds),
      );
      expect(result.toEntity().completionStatus, 'timed_out');

      final early = await dataSource.startExam(scoped());
      final completed = await dataSource.submitExam(
        attemptId: early.attemptId,
        answers: const {},
        flaggedQuestionIds: const {},
        timeTaken: const Duration(seconds: 30),
      );
      expect(completed.toEntity().completionStatus, 'completed');
    });
  });
}
