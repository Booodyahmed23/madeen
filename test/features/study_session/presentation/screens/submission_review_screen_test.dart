import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';
import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

const _qa = FakeQuestion(
  id: 'q1',
  text: 'Question 1',
  choices: {'q1-a': 'A', 'q1-b': 'B'},
  correctChoiceId: 'q1-a',
);
const _qb = FakeQuestion(
  id: 'q2',
  text: 'Question 2',
  choices: {'q2-a': 'A', 'q2-b': 'B'},
  correctChoiceId: 'q2-a',
);

Future<void> _startSessionLeavingQ2Unanswered(
  WidgetTester tester,
  MockStudySessionRepository repository,
) async {
  useTallSurface(tester);
  when(() => repository.startSession(any())).thenAnswer(
    (_) async => Result.success(fakeSession(questions: const [_qa, _qb])),
  );
  when(
    () => repository.answerQuestion(
      sessionId: 'sess-1',
      questionId: 'q1',
      choiceId: 'q1-a',
      timeSpentSeconds: any(named: 'timeSpentSeconds'),
    ),
  ).thenAnswer(
    (_) async =>
        Result.success(fakeSession(questions: [_qa.answer('q1-a'), _qb])),
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

  // This fixture's first choice is literally "A", which the MADEEN choice
  // tile's own letter anchor also shows — both are in the same tile.
  await tester.tap(find.text('A').first);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit answer'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(testSessionConfig));

  testWidgets(
    'shows answered/unanswered counts and lets the student jump to an unanswered question',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _startSessionLeavingQ2Unanswered(tester, repository);

      await tester.tap(find.byTooltip('Review & submit'));
      await tester.pumpAndSettle();

      expect(find.text('Answered: 1'), findsOneWidget);
      expect(find.text('Unanswered: 1'), findsOneWidget);
      expect(
        find.text(
          'You still have unanswered questions. Go back and answer them, or submit anyway.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Question 2'));
      await tester.pumpAndSettle();

      // Back on the active screen, positioned at question 2.
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Question 2'), findsOneWidget);
    },
  );

  testWidgets('submitting requires explicit confirmation', (tester) async {
    final repository = MockStudySessionRepository();
    when(() => repository.completeSession('sess-1')).thenAnswer(
      (_) async => Result.success(
        fakeSession(status: 'COMPLETED', questions: [_qa.answer('q1-a'), _qb]),
      ),
    );

    await _startSessionLeavingQ2Unanswered(tester, repository);
    await tester.tap(find.byTooltip('Review & submit'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Submit session'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears; completion has NOT happened yet.
    expect(find.text('Submit this session?'), findsOneWidget);
    verifyNever(() => repository.completeSession(any()));

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    verify(() => repository.completeSession('sess-1')).called(1);
    // Landed on the Results screen: 1 correct of 2.
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets(
    'a submission failure keeps the student on this screen with a retry path',
    (tester) async {
      final repository = MockStudySessionRepository();
      when(() => repository.completeSession(any()))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await _startSessionLeavingQ2Unanswered(tester, repository);
      await tester.tap(find.byTooltip('Review & submit'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Submit session'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Can't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      // The answer already recorded is still reflected — not silently lost.
      expect(find.text('Answered: 1'), findsOneWidget);
    },
  );
}
