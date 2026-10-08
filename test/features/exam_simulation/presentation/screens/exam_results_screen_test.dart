import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../exam_fixtures.dart';

const _question = FakeExamQuestion(
  id: 'q1',
  text: 'Question 1',
  choices: {'q1-a': 'Correct answer', 'q1-b': 'Wrong answer'},
  correctChoiceId: 'q1-a',
  explanation: 'Because it is.',
);

Future<void> _completeExam(
  WidgetTester tester, {
  String submitStatus = 'SUBMITTED',
}) async {
  final repository = FakeExamRepository(
    questions: const [_question],
    submittedAfter: const Duration(seconds: 45),
  )..submitStatus = submitStatus;
  await startExamViaSetup(tester, repository);

  await tester.tap(find.text('Correct answer'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.outlined_flag));
  await tester.pumpAndSettle();

  // Straight from the question navigator — the second way to submit.
  await tester.tap(find.byTooltip('Question navigator'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
  await tester.pumpAndSettle();
}

/// The results screen is tall — scroll a button into view before tapping.
Future<void> _tapResultsButton(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows the score and metrics derived from the submitted attempt',
    (tester) async {
      await _completeExam(tester);

      // The overall score, and the one topic's breakdown.
      expect(find.text('100%'), findsNWidgets(2));
      expect(find.text('Flexible Budget'), findsOneWidget);
      // submittedAt − startedAt = 45 s, over one question.
      expect(find.text('TOTAL TIME USED'), findsOneWidget);
      expect(find.text('AVG. TIME / QUESTION'), findsOneWidget);
      expect(find.text('00:45'), findsNWidgets(2));
      expect(find.text('Completed'), findsOneWidget);
    },
  );

  testWidgets('an attempt the server expired shows as Timed out', (
    tester,
  ) async {
    await _completeExam(tester, submitStatus: 'EXPIRED');

    expect(find.text('Timed out'), findsOneWidget);
  });

  testWidgets('Post-Exam Review shows every question with its flag state', (
    tester,
  ) async {
    await _completeExam(tester);

    await _tapResultsButton(
      tester,
      find.widgetWithText(OutlinedButton, 'Review answers'),
    );

    expect(find.text('1. Question 1'), findsOneWidget);
    expect(find.text('Because it is.'), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);
  });

  testWidgets('Done resets the exam and leaves the exam-simulation flow', (
    tester,
  ) async {
    await _completeExam(tester);

    await _tapResultsButton(tester, find.widgetWithText(FilledButton, 'Done'));

    expect(find.text('Home'), findsOneWidget);
  });
}
