import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/study_session/data/models/answer_choice_model.dart';
import 'package:mobile/features/study_session/data/models/question_feedback_model.dart';
import 'package:mobile/features/study_session/data/models/question_model.dart';
import 'package:mobile/features/study_session/data/models/question_review_item_model.dart';
import 'package:mobile/features/study_session/data/models/session_result_model.dart';
import 'package:mobile/features/study_session/data/models/study_session_bundle_model.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';

void main() {
  group('AnswerChoiceModel', () {
    test('parses id/text/order and maps to entity', () {
      final model = AnswerChoiceModel.fromJson({
        'id': 'q1-a',
        'text': 'Option A',
        'order': 2,
      });

      expect(model.id, 'q1-a');
      expect(model.text, 'Option A');
      expect(model.order, 2);

      final entity = model.toEntity();
      expect(entity.id, 'q1-a');
      expect(entity.order, 2);
    });

    test('order defaults to 0 when absent', () {
      final model = AnswerChoiceModel.fromJson({'id': 'q1-a', 'text': 'A'});
      expect(model.order, 0);
    });
  });

  group('QuestionModel', () {
    test('parses a full question and never exposes a correct-answer field', () {
      final model = QuestionModel.fromJson({
        'id': 'q1',
        'text': 'What is 2 + 2?',
        'type': 'MULTIPLE_CHOICE_SINGLE',
        'difficulty': 'Easy',
        'choices': [
          {'id': 'q1-a', 'text': '3', 'order': 0},
          {'id': 'q1-b', 'text': '4', 'order': 1},
        ],
      });

      expect(model.id, 'q1');
      expect(model.type, QuestionType.multipleChoiceSingle);
      expect(model.choices, hasLength(2));
      expect(model.difficulty, 'Easy');

      final entity = model.toEntity();
      expect(entity.choices.map((c) => c.text), ['3', '4']);
      // Question has no correct-answer field by construction — this is a
      // compile-time guarantee (see the entity's own doc comment), not
      // something a runtime test could regress independently, but parsing
      // must not require one either.
    });

    test('unknown/missing type degrades to multipleChoiceSingle rather than throwing', () {
      final model = QuestionModel.fromJson({
        'id': 'q1',
        'text': 'Text',
        'choices': <Map<String, dynamic>>[],
      });

      expect(model.type, QuestionType.multipleChoiceSingle);
    });

    test('difficulty is optional', () {
      final model = QuestionModel.fromJson({
        'id': 'q1',
        'text': 'Text',
        'type': 'MULTIPLE_CHOICE_SINGLE',
        'choices': <Map<String, dynamic>>[],
      });

      expect(model.difficulty, isNull);
    });
  });

  group('StudySessionBundleModel', () {
    test('parses sessionId and nested questions', () {
      final model = StudySessionBundleModel.fromJson({
        'sessionId': 'sess-1',
        'questions': [
          {
            'id': 'q1',
            'text': 'Text',
            'type': 'MULTIPLE_CHOICE_SINGLE',
            'choices': <Map<String, dynamic>>[],
          },
        ],
      });

      expect(model.sessionId, 'sess-1');
      expect(model.questions, hasLength(1));
      expect(model.toEntity().sessionId, 'sess-1');
    });
  });

  group('QuestionFeedbackModel', () {
    test('parses correctness, correct choice id, and explanation', () {
      final model = QuestionFeedbackModel.fromJson({
        'questionId': 'q1',
        'isCorrect': false,
        'correctChoiceId': 'q1-b',
        'explanation': 'Because...',
      });

      expect(model.isCorrect, isFalse);
      expect(model.correctChoiceId, 'q1-b');
      expect(model.toEntity().explanation, 'Because...');
    });

    test('explanation is optional', () {
      final model = QuestionFeedbackModel.fromJson({
        'questionId': 'q1',
        'isCorrect': true,
        'correctChoiceId': 'q1-a',
      });

      expect(model.explanation, isNull);
    });
  });

  group('SessionResultModel', () {
    test('parses every metric and converts seconds to Duration', () {
      final model = SessionResultModel.fromJson({
        'sessionId': 'sess-1',
        'totalQuestions': 20,
        'answered': 18,
        'unanswered': 2,
        'correct': 14,
        'incorrect': 4,
        'scorePercent': 70.0,
        'totalTimeSeconds': 742,
        'averageTimePerQuestionSeconds': 37.1,
      });

      final entity = model.toEntity();
      expect(entity.totalTime, const Duration(seconds: 742));
      expect(entity.averageTimePerQuestion.inMilliseconds, 37100);
      expect(entity.scorePercent, 70.0);
      expect(entity.correct + entity.incorrect, 18);
    });

    test('accepts integer scorePercent (not just double) from JSON', () {
      final model = SessionResultModel.fromJson({
        'sessionId': 'sess-1',
        'totalQuestions': 1,
        'answered': 1,
        'unanswered': 0,
        'correct': 1,
        'incorrect': 0,
        'scorePercent': 100,
        'totalTimeSeconds': 10,
        'averageTimePerQuestionSeconds': 10,
      });

      expect(model.scorePercent, 100.0);
    });
  });

  group('QuestionReviewItemModel', () {
    test('parses a correctly-answered question', () {
      final model = QuestionReviewItemModel.fromJson({
        'questionId': 'q1',
        'questionText': 'What is 2 + 2?',
        'choices': [
          {'id': 'q1-a', 'text': '4', 'order': 0},
        ],
        'correctChoiceId': 'q1-a',
        'selectedChoiceId': 'q1-a',
        'isCorrect': true,
        'explanation': 'Basic arithmetic.',
      });

      final entity = model.toEntity();
      expect(entity.isCorrect, isTrue);
      expect(entity.selectedChoiceId, 'q1-a');
    });

    test('selectedChoiceId is null for a question left unanswered', () {
      final model = QuestionReviewItemModel.fromJson({
        'questionId': 'q1',
        'questionText': 'Text',
        'choices': <Map<String, dynamic>>[],
        'correctChoiceId': 'q1-a',
        'selectedChoiceId': null,
        'isCorrect': false,
      });

      expect(model.toEntity().selectedChoiceId, isNull);
      expect(model.toEntity().isCorrect, isFalse);
    });
  });
}
