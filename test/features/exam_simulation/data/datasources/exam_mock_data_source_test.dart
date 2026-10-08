import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/exam_simulation/data/datasources/exam_mock_data_source.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_attempt_model.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';

import '../../exam_fixtures.dart';

void main() {
  late DateTime now;
  late ExamMockDataSource source;

  setUp(() {
    now = DateTime.utc(2026, 10, 8, 10);
    source = ExamMockDataSource(delay: Duration.zero, clock: () => now);
  });

  Future<ExamAttempt> start() async =>
      examAttemptFromJson(await source.startExam(testExamConfig));

  test('a new attempt spreads questions over the configured topics', () async {
    final attempt = await start();

    expect(attempt.questions, hasLength(10));
    expect(attempt.remainingSeconds, 15 * 60);
    expect(attempt.questions.map((q) => q.topicId).toSet(), {
      'topic-1',
      'topic-2',
    });
    expect(attempt.questions.any((q) => q.correctChoiceId != null), isFalse);
  });

  test('submitting reveals every question and is idempotent', () async {
    final attempt = await start();
    final q = attempt.questions.first;
    await source.answerQuestion(
      attemptId: attempt.id,
      questionId: q.questionId,
      choiceId: q.choices.first.id,
    );

    final submitted = examAttemptFromJson(await source.submitExam(attempt.id));
    final again = examAttemptFromJson(await source.submitExam(attempt.id));

    expect(submitted.status, ExamAttemptStatus.submitted);
    expect(submitted.score!.unanswered, 9);
    expect(submitted.questions.every((q) => q.correctChoiceId != null), isTrue);
    expect(again.submittedAt, submitted.submittedAt);
  });

  test(
    'the server clock expires an attempt; writes are then rejected',
    () async {
      final attempt = await start();
      now = now.add(const Duration(minutes: 16));

      final read = examAttemptFromJson(await source.getAttempt(attempt.id));
      expect(read.status, ExamAttemptStatus.expired);

      await expectLater(
        source.answerQuestion(
          attemptId: attempt.id,
          questionId: attempt.questions.first.questionId,
          choiceId: attempt.questions.first.choices.first.id,
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
