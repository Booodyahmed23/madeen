import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';
import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

Future<MockStudySessionRepository> _startSession(
  WidgetTester tester, {
  FeedbackMode feedbackMode = FeedbackMode.immediate,
}) async {
  useTallSurface(tester);
  final repository = MockStudySessionRepository();
  when(() => repository.startSession(any())).thenAnswer(
    (_) async => Result.success(fakeSession(feedbackMode: feedbackMode)),
  );

  await tester.pumpWidget(
    wrapStudySessionScreen(
      repository: repository,
      initialLocation: '/topics/topic-1',
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(
      feedbackMode == FeedbackMode.immediate ? 'Immediate' : 'At the end',
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
  await tester.pumpAndSettle();
  return repository;
}

void stubAnswer(
  MockStudySessionRepository repository,
  String questionId,
  String choiceId,
  Result<StudySession> Function() respond,
) {
  when(
    () => repository.answerQuestion(
      sessionId: 'sess-1',
      questionId: questionId,
      choiceId: choiceId,
      timeSpentSeconds: any(named: 'timeSpentSeconds'),
    ),
  ).thenAnswer((_) async => respond());
}

void main() {
  setUpAll(() => registerFallbackValue(testSessionConfig));

  testWidgets(
    'shows the question, progress, and timer for the active session',
    (tester) async {
      await _startSession(tester);

      expect(find.text('What is 2 + 2?'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      // The bank reference (question code) above the stem.
      expect(find.text('REF. #1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets('immediate mode: picking a choice waits for "Submit answer"', (
    tester,
  ) async {
    final repository = await _startSession(tester);

    await tester.tap(find.text('4'));
    await tester.pump();

    expect(find.text('Submit answer'), findsOneWidget);
    verifyNever(
      () => repository.answerQuestion(
        sessionId: any(named: 'sessionId'),
        questionId: any(named: 'questionId'),
        choiceId: any(named: 'choiceId'),
        timeSpentSeconds: any(named: 'timeSpentSeconds'),
      ),
    );
  });

  testWidgets(
    'immediate mode: submitting sends the answer and shows the revealed '
    'result from the server',
    (tester) async {
      final repository = await _startSession(tester);
      stubAnswer(
        repository,
        'q1',
        'q1-a',
        () => Result.success(fakeSession(questions: [q1.answer('q1-a'), q2])),
      );

      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit answer'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('2 + 2 = 4.'), findsOneWidget);
      // Locked once revealed: another tap sends nothing.
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      verify(
        () => repository.answerQuestion(
          sessionId: 'sess-1',
          questionId: 'q1',
          choiceId: any(named: 'choiceId'),
          timeSpentSeconds: any(named: 'timeSpentSeconds'),
        ),
      ).called(1);
    },
  );

  testWidgets('"at the end" mode saves every pick right away and never shows '
      'correctness', (tester) async {
    final repository = await _startSession(
      tester,
      feedbackMode: FeedbackMode.atEnd,
    );
    stubAnswer(
      repository,
      'q1',
      'q1-a',
      () => Result.success(
        fakeSession(
          feedbackMode: FeedbackMode.atEnd,
          questions: [q1.answer('q1-a'), q2],
        ),
      ),
    );

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(find.text('Submit answer'), findsNothing);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Incorrect'), findsNothing);
    verify(
      () => repository.answerQuestion(
        sessionId: 'sess-1',
        questionId: 'q1',
        choiceId: 'q1-a',
        timeSpentSeconds: any(named: 'timeSpentSeconds'),
      ),
    ).called(1);
  });

  testWidgets('an answer that could not be saved says so', (tester) async {
    final repository = await _startSession(
      tester,
      feedbackMode: FeedbackMode.atEnd,
    );
    stubAnswer(
      repository,
      'q1',
      'q1-a',
      () => const Result.failure(NetworkFailure()),
    );

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Your answer couldn't be saved. Check your connection and try again.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('the flag button flags the question on the server', (
    tester,
  ) async {
    final repository = await _startSession(tester);
    when(
      () => repository.flagQuestion(
        sessionId: 'sess-1',
        questionId: 'q1',
        flagged: true,
      ),
    ).thenAnswer(
      (_) async => Result.success(fakeSession(questions: [q1.flag(true), q2])),
    );

    await tester.tap(find.byTooltip('Flag question'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove flag'), findsOneWidget);
  });

  testWidgets('next moves to the following question', (tester) async {
    await _startSession(tester, feedbackMode: FeedbackMode.atEnd);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('What is 3 + 3?'), findsOneWidget);
  });

  testWidgets('the last question shows "Review & submit" instead of "Next"', (
    tester,
  ) async {
    await _startSession(tester, feedbackMode: FeedbackMode.atEnd);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Review & submit'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
  });

  testWidgets(
    'leaving the session shows a confirmation dialog before navigating away',
    (tester) async {
      await _startSession(tester);

      final dynamic navigatorState = tester.state(find.byType(Navigator));
      navigatorState.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Leave this session?'), findsOneWidget);
      expect(
        find.text(
          'Your answers are saved. You can continue this session later '
          'from Home.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('What is 2 + 2?'), findsOneWidget);
    },
  );
}
