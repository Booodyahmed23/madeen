import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';
import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

const _question = FakeQuestion(
  id: 'q1',
  text: 'Question 1',
  choices: {'q1-a': 'Correct answer', 'q1-b': 'Wrong answer'},
  correctChoiceId: 'q1-a',
  explanation: 'Because it is.',
);

const _skipped = FakeQuestion(
  id: 'q2',
  text: 'Question 2',
  choices: {'q2-a': 'Right', 'q2-b': 'Other'},
  correctChoiceId: 'q2-a',
);

Future<void> _completeSession(
  WidgetTester tester,
  MockStudySessionRepository repository, {
  List<FakeQuestion> completedQuestions = const [],
}) async {
  useTallSurface(tester);
  final answered = _question.answer('q1-a', addSeconds: 30);
  when(() => repository.startSession(any())).thenAnswer(
    (_) async => Result.success(fakeSession(questions: const [_question])),
  );
  when(
    () => repository.answerQuestion(
      sessionId: any(named: 'sessionId'),
      questionId: 'q1',
      choiceId: 'q1-a',
      timeSpentSeconds: any(named: 'timeSpentSeconds'),
    ),
  ).thenAnswer((_) async => Result.success(fakeSession(questions: [answered])));
  when(() => repository.completeSession(any())).thenAnswer(
    (_) async => Result.success(
      fakeSession(
        status: 'COMPLETED',
        questions: completedQuestions.isEmpty ? [answered] : completedQuestions,
      ),
    ),
  );

  await tester.pumpWidget(
    wrapStudySessionScreen(
      repository: repository,
      initialLocation: '/topics/topic-1',
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Correct answer'));
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit answer'));
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Review & submit'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit session'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(testSessionConfig));

  testWidgets(
    'shows the score and metrics derived from the completed session',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _completeSession(tester, repository);

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // total/answered/correct all 1
      expect(find.text('0'), findsWidgets); // unanswered/incorrect
      // Σ timeSpentSeconds from the server: total and average.
      expect(find.text('00:30'), findsWidgets);
    },
  );

  testWidgets('navigating to Review shows the per-question review', (
    tester,
  ) async {
    final repository = MockStudySessionRepository();
    await _completeSession(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review answers'));
    await tester.pumpAndSettle();

    expect(find.text('1. Question 1'), findsOneWidget);
    expect(find.text('Because it is.'), findsOneWidget);
  });

  testWidgets('Done resets the session and returns Home', (tester) async {
    final repository = MockStudySessionRepository();
    await _completeSession(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a skipped question the server did not reveal says its answer is '
      'not shown', (tester) async {
    final repository = MockStudySessionRepository();
    await _completeSession(
      tester,
      repository,
      completedQuestions: [
        _question.answer('q1-a', addSeconds: 30),
        const FakeQuestion(
          id: 'q2',
          text: 'Question 2',
          choices: {'q2-a': 'Right', 'q2-b': 'Other'},
          correctChoiceId: 'q2-a',
          revealed: false,
        ),
      ],
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review answers'));
    await tester.pumpAndSettle();

    expect(find.text('2. Question 2'), findsOneWidget);
    expect(find.text("You didn't answer this question."), findsOneWidget);
    expect(find.text('Not shown for skipped questions.'), findsOneWidget);
  });

  testWidgets('a skipped question the server revealed shows its answer', (
    tester,
  ) async {
    final repository = MockStudySessionRepository();
    await _completeSession(
      tester,
      repository,
      completedQuestions: [_question.answer('q1-a', addSeconds: 30), _skipped],
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review answers'));
    await tester.pumpAndSettle();

    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Not shown for skipped questions.'), findsNothing);
  });
}
