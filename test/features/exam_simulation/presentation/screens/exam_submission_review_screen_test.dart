import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../exam_fixtures.dart';

FakeExamQuestion _q(int n) => FakeExamQuestion(
  id: 'q$n',
  text: 'Question $n',
  choices: {'q$n-a': 'A', 'q$n-b': 'B'},
  correctChoiceId: 'q$n-a',
);

Future<FakeExamRepository> _reachSubmissionReview(WidgetTester tester) async {
  final repository = FakeExamRepository(questions: [_q(1), _q(2), _q(3)]);
  await startExamViaSetup(tester, repository);

  // Answer question 1, flag question 2, leave question 3 unanswered. The
  // first choice is literally "A", which the choice tile's own letter
  // anchor also shows — both are in the same tile.
  await tester.tap(find.text('A').first);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.outlined_flag));
  await tester.pumpAndSettle();

  // Through the question navigator sheet's Review action.
  await tester.tap(find.byTooltip('Question navigator'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Review'));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets(
    'shows answered/unanswered/flagged counts and per-question status',
    (tester) async {
      await _reachSubmissionReview(tester);

      expect(find.text('Answered: 1'), findsOneWidget);
      expect(find.text('Unanswered: 2'), findsOneWidget);
      expect(find.text('Flagged: 1'), findsOneWidget);
      expect(find.text('Answered'), findsOneWidget); // question 1's status
      expect(find.text('Flagged'), findsWidgets);
      expect(find.text('Unanswered'), findsWidgets);
    },
  );

  testWidgets('Review Unanswered jumps to the first unanswered question', (
    tester,
  ) async {
    await _reachSubmissionReview(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review Unanswered'));
    await tester.pumpAndSettle();

    expect(find.text('Question 3'), findsOneWidget);
  });

  testWidgets(
    'submitting requires explicit confirmation and warns about unanswered '
    'questions',
    (tester) async {
      final repository = await _reachSubmissionReview(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
      await tester.pumpAndSettle();

      expect(find.text('Submit Simulation?'), findsOneWidget);
      expect(
        find.text('You still have 2 unanswered questions.'),
        findsOneWidget,
      );
      expect(repository.submitCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(repository.submitCalls, 1);
      expect(find.text('SCORE'), findsOneWidget);
    },
  );

  testWidgets('Cancel closes the confirmation without submitting', (
    tester,
  ) async {
    final repository = await _reachSubmissionReview(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.submitCalls, 0);
    expect(find.text('Exam Review'), findsOneWidget);
  });
}
