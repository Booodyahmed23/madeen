import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/study_session/data/models/study_session_model.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';

import '../../study_session_fixtures.dart';

/// A trimmed copy of a real `POST /study/sessions/:id/complete` response
/// from the API, with one answered (revealed) and one skipped question.
final _completedFromApi = {
  'id': '56d0d7df-705a-454f-bc73-362dfd7b5b55',
  'userId': '93262cbd-5b2a-42c2-b34f-a51c94d3063e',
  'status': 'COMPLETED',
  'feedbackMode': 'IMMEDIATE',
  'topicIds': ['845e077c-28d9-4f34-a03e-b2bef40115b5'],
  'difficulty': null,
  'requestedCount': 2,
  'createdAt': '2026-10-08T20:20:29.392Z',
  'updatedAt': '2026-10-08T20:20:31.747Z',
  'completedAt': '2026-10-08T20:20:31.746Z',
  'progress': {'total': 2, 'answered': 1, 'flagged': 1, 'correct': 0},
  'questions': [
    {
      'id': 'sq-2',
      'questionId': 'bank-2',
      'order': 1,
      'isFlagged': false,
      'answeredAt': null,
      'timeSpentSeconds': 0,
      'selectedChoiceId': null,
      'isCorrect': null,
      'question': {
        'id': 'bank-2',
        'text': 'Skipped question',
        'topic': {'id': 't1', 'name': 'Direct Material Variances'},
        'code': 4,
        'losCode': null,
        'difficulty': 'EASY',
        'explanation': null,
      },
      'choices': [
        {'id': 'c3', 'text': 'C'},
        {'id': 'c4', 'text': 'D'},
      ],
    },
    {
      'id': 'sq-1',
      'questionId': 'bank-1',
      'order': 0,
      'isFlagged': true,
      'answeredAt': '2026-10-08T20:20:30.000Z',
      'timeSpentSeconds': 12,
      'selectedChoiceId': 'c1',
      'isCorrect': false,
      'question': {
        'id': 'bank-1',
        'text': 'An unfavorable material quantity variance is most likely caused by:',
        'topic': {
          'id': 't1',
          'name': 'Direct Material Variances',
          'description': null,
        },
        'code': 3,
        'losCode': 'LOS 1.A',
        'difficulty': 'MEDIUM',
        'explanation': 'Poor-quality materials increase waste.',
      },
      'choices': [
        {'id': 'c1', 'text': 'Buying at a bulk discount', 'isCorrect': false},
        {'id': 'c2', 'text': 'Low-quality raw materials', 'isCorrect': true},
      ],
    },
  ],
};

void main() {
  test('parses the API session, ordered by `order`', () {
    final session = studySessionFromJson(_completedFromApi);

    expect(session.status, StudySessionStatus.completed);
    expect(session.feedbackMode, FeedbackMode.immediate);
    expect(session.questions.map((q) => q.questionId), ['bank-1', 'bank-2']);
    final first = session.questions.first;
    expect(first.topic.name, 'Direct Material Variances');
    expect(first.code, 3);
    expect(first.losCode, 'LOS 1.A');
    expect(first.isFlagged, isTrue);
    expect(first.isRevealed, isTrue);
    expect(first.correctChoiceId, 'c2');
    expect(session.questions.last.isRevealed, isFalse);
  });

  test('derives the result per the contract table', () {
    final result = studySessionFromJson(_completedFromApi).toResult();

    expect(result.totalQuestions, 2);
    expect(result.answered, 1);
    expect(result.correct, 0);
    expect(result.incorrect, 1);
    expect(result.unanswered, 1);
    expect(result.scorePercent, 0);
    expect(result.totalTime, const Duration(seconds: 12));
    expect(result.averageTimePerQuestion, const Duration(seconds: 12));
  });

  test('the review keeps a skipped, unrevealed question without an answer', () {
    final review = studySessionFromJson(_completedFromApi).toReview();

    expect(review.first.correctChoiceId, 'c2');
    expect(review.first.isCorrect, isFalse);
    expect(review.last.isSkipped, isTrue);
    expect(review.last.correctChoiceId, isNull);
    expect(review.last.isCorrect, isNull);
  });

  test('immediate feedback exists only for answered, revealed questions', () {
    final session = fakeSession(questions: [q1.answer('q1-b'), q2]);

    final feedback = session.feedbackFor('q1')!;
    expect(feedback.isCorrect, isTrue);
    expect(feedback.correctChoiceId, 'q1-b');
    expect(session.feedbackFor('q2'), isNull);
  });

  test('answers lock after immediate feedback or once not in progress', () {
    final immediate = fakeSession(questions: [q1.answer('q1-a'), q2]);
    expect(immediate.isLocked(immediate.questions[0]), isTrue);
    expect(immediate.isLocked(immediate.questions[1]), isFalse);

    final deferred = fakeSession(
      feedbackMode: FeedbackMode.atEnd,
      questions: [q1.answer('q1-a'), q2],
    );
    expect(deferred.isLocked(deferred.questions[0]), isFalse);

    final paused = fakeSession(status: 'PAUSED');
    expect(paused.isLocked(paused.questions[0]), isTrue);
  });

  test('maps feedback modes to and from the wire', () {
    expect(feedbackModeToWire(FeedbackMode.immediate), 'IMMEDIATE');
    expect(feedbackModeToWire(FeedbackMode.atEnd), 'DEFERRED');
    expect(feedbackModeFromWire('DEFERRED'), FeedbackMode.atEnd);
  });
}
