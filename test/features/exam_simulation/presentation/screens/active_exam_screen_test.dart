import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';

import '../../exam_fixtures.dart';

void main() {
  testWidgets(
    'shows the question, progress and server countdown — and no topic label',
    (tester) async {
      final repository = FakeExamRepository(remainingSeconds: 90);
      await startExamViaSetup(tester, repository);

      expect(find.text('What is a flexible budget?'), findsOneWidget);
      expect(find.text('Question 1 / 2'), findsOneWidget);
      // Starts from the server's remainingSeconds.
      expect(find.text('01:30'), findsOneWidget);

      // The payload carries the topic, but it's never shown mid-exam.
      expect(find.text('Flexible Budget'), findsNothing);
      expect(find.text('CMA'), findsNothing);
      expect(find.text('Part 1'), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
    },
  );

  testWidgets('setup sends the topic ids under the chosen part', (
    tester,
  ) async {
    final repository = FakeExamRepository();
    await startExamViaSetup(tester, repository);

    final config = repository.startedWith.single;
    expect(config.topicIds, ['topic-1', 'topic-2']);
    expect(config.durationMinutes, 15);
  });

  testWidgets('selecting a choice saves it and never reveals correctness', (
    tester,
  ) async {
    final repository = FakeExamRepository();
    await startExamViaSetup(tester, repository);

    await tester.tap(find.text('One that adjusts to volume'));
    await tester.pumpAndSettle();

    expect(repository.answers.single, (questionId: 'eq1', choiceId: 'eq1-a'));
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Incorrect'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('an answer that could not be saved says so and is not kept', (
    tester,
  ) async {
    final repository = FakeExamRepository()
      ..answerFailure = const NetworkFailure();
    await startExamViaSetup(tester, repository);

    await tester.tap(find.text('One that adjusts to volume'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Your answer couldn't be saved. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('flagging saves the flag and toggles the icon', (tester) async {
    final repository = FakeExamRepository();
    await startExamViaSetup(tester, repository);

    expect(find.byIcon(Icons.outlined_flag), findsOneWidget);

    await tester.tap(find.byIcon(Icons.outlined_flag));
    await tester.pumpAndSettle();

    expect(repository.flags.single, (questionId: 'eq1', flagged: true));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.flag),
      ),
      findsOneWidget,
    );
    expect(find.text('Flagged: 1'), findsOneWidget);
  });

  testWidgets('next/previous move between questions without submitting', (
    tester,
  ) async {
    final repository = FakeExamRepository();
    await startExamViaSetup(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('What is a master budget?'), findsOneWidget);
    expect(repository.submitCalls, 0);
  });

  testWidgets('the last question shows "Review" instead of "Next"', (
    tester,
  ) async {
    await startExamViaSetup(tester, FakeExamRepository());

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Review'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
  });

  testWidgets('leaving the exam explains the timer keeps running', (
    tester,
  ) async {
    await startExamViaSetup(tester, FakeExamRepository());

    final dynamic navigatorState = tester.state(find.byType(Navigator).first);
    navigatorState.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Leave this exam?'), findsOneWidget);
    expect(
      find.text(
        'Your answers are saved, but the timer keeps running. You can '
        'return to this exam from Home until time runs out.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('What is a flexible budget?'), findsOneWidget);
  });

  testWidgets('time running out submits; an expired attempt shows Timed out', (
    tester,
  ) async {
    final repository = FakeExamRepository(remainingSeconds: 2)
      ..submitStatus = 'EXPIRED';
    await startExamViaSetup(tester, repository);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(repository.submitCalls, 1);
    expect(find.text('Timed out'), findsOneWidget);
  });
}
