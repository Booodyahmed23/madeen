import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_review_item.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_topic_breakdown.dart';

ExamReviewItem _item(
  String id, {
  String? topicId,
  String? topicName,
  String? selected,
  String correct = 'a',
}) => ExamReviewItem(
  questionId: id,
  questionText: 'Question $id',
  choices: const [
    ExamAnswerChoice(id: 'a', text: 'A'),
    ExamAnswerChoice(id: 'b', text: 'B'),
  ],
  correctChoiceId: correct,
  selectedChoiceId: selected,
  isCorrect: selected != null && selected == correct,
  wasFlagged: false,
  topicId: topicId,
  topicName: topicName,
);

void main() {
  group('question count → countdown', () {
    test('the presets pair exactly as specified', () {
      expect(kExamQuestionCountOptions, [10, 20, 50, 80]);
      expect(examDurationFor(10), const Duration(minutes: 15));
      expect(examDurationFor(20), const Duration(minutes: 30));
      expect(examDurationFor(50), const Duration(minutes: 60));
      expect(examDurationFor(80), const Duration(minutes: 120));
    });

    test('any other count gets 90 seconds per question', () {
      expect(examDurationFor(1), const Duration(seconds: 90));
      expect(examDurationFor(30), const Duration(minutes: 45));
    });

    test('the API gets whole minutes, clamped to 5–300', () {
      ExamConfig withDuration(Duration d) => ExamConfig(
        programId: 'p',
        programName: 'CMA',
        partId: 'part',
        partName: 'Part 1',
        questionCount: 1,
        duration: d,
        topicIds: const ['t'],
      );
      expect(withDuration(const Duration(seconds: 90)).durationMinutes, 5);
      expect(withDuration(const Duration(minutes: 45)).durationMinutes, 45);
      expect(withDuration(const Duration(seconds: 2701)).durationMinutes, 46);
      expect(withDuration(const Duration(hours: 6)).durationMinutes, 300);
    });

    test('scope narrowing defaults to the whole Part', () {
      const config = ExamConfig(
        programId: 'p',
        programName: 'CMA',
        partId: 'part',
        partName: 'Part 1',
        questionCount: 10,
        duration: Duration(minutes: 15),
        topicIds: ['t'],
      );
      expect(config.unitId, isNull);
      expect(config.subUnitId, isNull);
    });
  });

  group('ExamReviewItem answer state', () {
    test('wrong means answered and incorrect; unanswered is separate', () {
      final right = _item('1', selected: 'a');
      final wrong = _item('2', selected: 'b');
      final blank = _item('3');

      expect((right.isWrong, right.isUnanswered), (false, false));
      expect((wrong.isWrong, wrong.isUnanswered), (true, false));
      expect((blank.isWrong, blank.isUnanswered), (false, true));
    });
  });

  group('examTopicBreakdown', () {
    test('groups by topic in first-seen order with every count', () {
      final breakdown = examTopicBreakdown([
        _item('1', topicId: 't1', topicName: 'Budgets', selected: 'a'),
        _item('2', topicId: 't2', topicName: 'Costs', selected: 'b'),
        _item('3', topicId: 't1', topicName: 'Budgets', selected: 'b'),
        _item('4', topicId: 't1', topicName: 'Budgets'),
        _item('5', topicId: 't2', topicName: 'Costs', selected: 'a'),
      ]);

      expect(breakdown.map((t) => t.topicId), ['t1', 't2']);
      final budgets = breakdown.first;
      expect(budgets.topicName, 'Budgets');
      expect(budgets.total, 3);
      expect(budgets.correct, 1);
      expect(budgets.wrong, 1);
      expect(budgets.unanswered, 1);
      expect(budgets.answered, 2);
      // Unanswered count against the topic, exactly like the overall score.
      expect(budgets.scorePercent, closeTo(33.3, 0.1));

      final costs = breakdown.last;
      expect((costs.total, costs.correct, costs.wrong), (2, 1, 1));
      expect(costs.scorePercent, 50);
    });

    test('questions without a topic are left out, not invented', () {
      expect(examTopicBreakdown([_item('1', selected: 'a')]), isEmpty);
      expect(examTopicBreakdown(const []), isEmpty);
    });
  });
}
