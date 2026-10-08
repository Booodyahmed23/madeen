import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_attempt_model.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';

import '../../exam_fixtures.dart';

void main() {
  test('parses an in-progress attempt with nothing revealed', () {
    final attempt = fakeAttempt(remainingSeconds: 299);

    expect(attempt.status, ExamAttemptStatus.inProgress);
    expect(attempt.remainingSeconds, 299);
    expect(attempt.score, isNull);
    expect(attempt.questions.first.correctChoiceId, isNull);
    // The topic is in the payload (kept for the review), not on the
    // question shown during the exam.
    expect(attempt.questions.first.topicName, 'Flexible Budget');
  });

  test('derives the result per the contract table', () {
    final attempt = fakeAttempt(
      status: 'SUBMITTED',
      submittedAfter: const Duration(minutes: 4),
      questions: [eq1.answer('eq1-a'), eq2],
    );

    final result = attempt.toResult();
    expect(result.totalQuestions, 2);
    expect(result.correct, 1);
    expect(result.incorrect, 0);
    expect(result.unanswered, 1);
    expect(result.answered, 1);
    expect(result.scorePercent, 50);
    expect(result.durationTaken, const Duration(minutes: 4));
    expect(result.completionStatus, 'completed');
  });

  test('EXPIRED is a timed-out result', () {
    expect(
      fakeAttempt(status: 'EXPIRED').toResult().completionStatus,
      'timed_out',
    );
  });

  test('after submission every question is revealed, unanswered included', () {
    final review = fakeAttempt(
      status: 'SUBMITTED',
      questions: [eq1.answer('eq1-b').copyWith(flagged: true), eq2],
    ).toReview();

    expect(review[0].correctChoiceId, 'eq1-a');
    expect(review[0].isWrong, isTrue);
    expect(review[0].wasFlagged, isTrue);
    expect(review[0].explanation, 'It flexes with activity.');
    expect(review[1].isUnanswered, isTrue);
    expect(review[1].correctChoiceId, 'eq2-a');
    expect(review[1].topicName, 'Master Budget');
  });

  test('a list row knows whether it is still open', () {
    final row = examAttemptSummaryFromJson(
      fakeAttemptJson()..remove('questions'),
    );

    expect(row.isOpenAt(examStartedAt.add(const Duration(minutes: 1))), isTrue);
    // Past expiresAt: closed, even before the server marks it EXPIRED.
    expect(row.isOpenAt(examStartedAt.add(const Duration(hours: 1))), isFalse);
  });
}
