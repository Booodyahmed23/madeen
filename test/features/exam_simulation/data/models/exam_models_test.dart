import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_answer_choice_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_attempt_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_question_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_result_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_review_item_model.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';

void main() {
  group('ExamAnswerChoiceModel', () {
    test('parses id/text/order and maps to entity', () {
      final model = ExamAnswerChoiceModel.fromJson({
        'id': 'q1-a',
        'text': 'Option A',
        'order': 2,
      });

      expect(model.id, 'q1-a');
      expect(model.order, 2);
      expect(model.toEntity().text, 'Option A');
    });

    test('order defaults to 0 when absent', () {
      final model = ExamAnswerChoiceModel.fromJson({'id': 'q1-a', 'text': 'A'});
      expect(model.order, 0);
    });
  });

  group('ExamQuestionModel', () {
    test(
      'parses a full question and carries no topic/correct-answer field',
      () {
        final model = ExamQuestionModel.fromJson({
          'id': 'q1',
          'text': 'What is 2 + 2?',
          'type': 'MULTIPLE_CHOICE_SINGLE',
          'choices': [
            {'id': 'q1-a', 'text': '3', 'order': 0},
            {'id': 'q1-b', 'text': '4', 'order': 1},
          ],
        });

        expect(model.id, 'q1');
        expect(model.type, ExamQuestionType.multipleChoiceSingle);
        final entity = model.toEntity();
        expect(entity.choices.map((c) => c.text), ['3', '4']);
        // ExamQuestion has no topic or correct-answer field at all — a
        // compile-time guarantee, not a runtime assertion this test could
        // meaningfully make beyond "parsing doesn't require one".
      },
    );

    test('unknown/missing type degrades to multipleChoiceSingle rather than throwing', () {
      final model = ExamQuestionModel.fromJson({
        'id': 'q1',
        'text': 'Text',
        'choices': <Map<String, dynamic>>[],
      });

      expect(model.type, ExamQuestionType.multipleChoiceSingle);
    });
  });

  group('ExamAttemptModel', () {
    test('parses attemptId, durationSeconds, and nested questions', () {
      final model = ExamAttemptModel.fromJson({
        'attemptId': 'attempt-1',
        'durationSeconds': 3600,
        'questions': [
          {
            'id': 'q1',
            'text': 'Text',
            'type': 'MULTIPLE_CHOICE_SINGLE',
            'choices': <Map<String, dynamic>>[],
          },
        ],
      });

      expect(model.attemptId, 'attempt-1');
      expect(model.durationSeconds, 3600);
      expect(model.questions, hasLength(1));
      expect(model.toEntity().durationSeconds, 3600);
    });
  });

  group('ExamResultModel', () {
    test('parses every metric and converts seconds to Duration', () {
      final model = ExamResultModel.fromJson({
        'attemptId': 'attempt-1',
        'totalQuestions': 100,
        'answered': 94,
        'unanswered': 6,
        'correct': 71,
        'incorrect': 23,
        'scorePercent': 71.0,
        'durationTakenSeconds': 13920,
        'completionStatus': 'completed',
      });

      final entity = model.toEntity();
      expect(entity.durationTaken, const Duration(seconds: 13920));
      expect(entity.scorePercent, 71.0);
      expect(entity.completionStatus, 'completed');
      expect(entity.correct + entity.incorrect, 94);
    });

    test('accepts an integer scorePercent from JSON', () {
      final model = ExamResultModel.fromJson({
        'attemptId': 'attempt-1',
        'totalQuestions': 1,
        'answered': 1,
        'unanswered': 0,
        'correct': 1,
        'incorrect': 0,
        'scorePercent': 100,
        'durationTakenSeconds': 10,
        'completionStatus': 'completed',
      });

      expect(model.scorePercent, 100.0);
    });
  });

  group('ExamReviewItemModel', () {
    test('parses a correctly-answered, flagged question', () {
      final model = ExamReviewItemModel.fromJson({
        'questionId': 'q1',
        'questionText': 'What is 2 + 2?',
        'choices': [
          {'id': 'q1-a', 'text': '4', 'order': 0},
        ],
        'correctChoiceId': 'q1-a',
        'selectedChoiceId': 'q1-a',
        'isCorrect': true,
        'wasFlagged': true,
        'explanation': 'Basic arithmetic.',
      });

      final entity = model.toEntity();
      expect(entity.isCorrect, isTrue);
      expect(entity.wasFlagged, isTrue);
    });

    test('selectedChoiceId is null and wasFlagged defaults to false', () {
      final model = ExamReviewItemModel.fromJson({
        'questionId': 'q1',
        'questionText': 'Text',
        'choices': <Map<String, dynamic>>[],
        'correctChoiceId': 'q1-a',
        'selectedChoiceId': null,
        'isCorrect': false,
      });

      expect(model.toEntity().selectedChoiceId, isNull);
      expect(model.toEntity().wasFlagged, isFalse);
    });
  });

  test('a review item carries its optional topic through to the entity', () {
    final base = {
      'questionId': 'q-001',
      'questionText': 'Q',
      'choices': [
        {'id': 'a', 'text': 'A', 'order': 0},
      ],
      'correctChoiceId': 'a',
      'selectedChoiceId': null,
      'isCorrect': false,
      'wasFlagged': false,
    };
    final withTopic = ExamReviewItemModel.fromJson({
      ...base,
      'topicId': 'topic-flexible-budget',
      'topicName': 'Flexible Budget',
    }).toEntity();
    expect(withTopic.topicId, 'topic-flexible-budget');
    expect(withTopic.topicName, 'Flexible Budget');
    expect(withTopic.isUnanswered, isTrue);

    // Older/backends that don't classify questions: no topic, no crash.
    final withoutTopic = ExamReviewItemModel.fromJson(base).toEntity();
    expect(withoutTopic.topicId, isNull);
    expect(withoutTopic.topicName, isNull);
  });
}
