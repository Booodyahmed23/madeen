import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/entities/answer_choice.dart';
import 'package:mobile/features/study_session/domain/entities/question.dart';
import 'package:mobile/features/study_session/domain/entities/question_feedback.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session_bundle.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

final _bundle = StudySessionBundle(
  sessionId: 'sess-1',
  questions: [
    Question(
      id: 'q1',
      text: 'What is 2 + 2?',
      type: QuestionType.multipleChoiceSingle,
      choices: const [
        AnswerChoice(id: 'q1-a', text: '3', order: 0),
        AnswerChoice(id: 'q1-b', text: '4', order: 1),
      ],
    ),
    Question(
      id: 'q2',
      text: 'What is 3 + 3?',
      type: QuestionType.multipleChoiceSingle,
      choices: const [
        AnswerChoice(id: 'q2-a', text: '5', order: 0),
        AnswerChoice(id: 'q2-b', text: '6', order: 1),
      ],
    ),
  ],
);

Future<void> _startSession(
  WidgetTester tester,
  MockStudySessionRepository repository, {
  FeedbackMode feedbackMode = FeedbackMode.immediate,
}) async {
  useTallSurface(tester);
  when(() => repository.startSession(any()))
      .thenAnswer((_) async => Result.success(_bundle));

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
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const SessionConfig(
        topicId: 'x',
        topicName: 'x',
        questionCount: 10,
        order: QuestionOrder.original,
        feedbackMode: FeedbackMode.immediate,
      ),
    );
    registerFallbackValue(Duration.zero);
  });

  testWidgets(
    'shows the question, progress, and timer for the active session',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _startSession(tester, repository);

      expect(find.text('What is 2 + 2?'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets('selecting a choice shows it as selected', (tester) async {
    final repository = MockStudySessionRepository();
    await _startSession(tester, repository);

    await tester.tap(find.text('4'));
    await tester.pump();

    expect(find.text('Submit answer'), findsOneWidget);
  });

  testWidgets(
    'immediate feedback mode reveals correctness and the correct answer after submitting',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _startSession(tester, repository);

      when(
        () => repository.submitAnswer(
          sessionId: 'sess-1',
          questionId: 'q1',
          selectedChoiceId: 'q1-a',
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          QuestionFeedback(
            questionId: 'q1',
            isCorrect: false,
            correctChoiceId: 'q1-b',
            explanation: '2 + 2 = 4.',
          ),
        ),
      );

      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit answer'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('2 + 2 = 4.'), findsOneWidget);
    },
  );

  testWidgets('feedback-at-end mode never shows correctness while answering', (
    tester,
  ) async {
    final repository = MockStudySessionRepository();
    await _startSession(tester, repository, feedbackMode: FeedbackMode.atEnd);

    await tester.tap(find.text('3'));
    await tester.pump();

    // No "Submit answer" affordance and no correctness ever shown here.
    expect(find.text('Submit answer'), findsNothing);
    expect(find.text('Correct'), findsNothing);
    expect(find.text('Incorrect'), findsNothing);
    verifyNever(
      () => repository.submitAnswer(
        sessionId: any(named: 'sessionId'),
        questionId: any(named: 'questionId'),
        selectedChoiceId: any(named: 'selectedChoiceId'),
      ),
    );
  });

  testWidgets(
    'next moves to the following question without submitting the session',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _startSession(tester, repository, feedbackMode: FeedbackMode.atEnd);

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('What is 3 + 3?'), findsOneWidget);
      verifyNever(
        () => repository.submitSession(
          sessionId: any(named: 'sessionId'),
          answers: any(named: 'answers'),
          totalTime: any(named: 'totalTime'),
        ),
      );
    },
  );

  testWidgets('the last question shows "Review & submit" instead of "Next"', (
    tester,
  ) async {
    final repository = MockStudySessionRepository();
    await _startSession(tester, repository, feedbackMode: FeedbackMode.atEnd);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Review & submit'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
  });

  testWidgets(
    'leaving the session shows a confirmation dialog before navigating away',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _startSession(tester, repository);

      final dynamic navigatorState = tester.state(find.byType(Navigator));
      navigatorState.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Leave this session?'), findsOneWidget);
      // Cancel keeps the session intact.
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('What is 2 + 2?'), findsOneWidget);
    },
  );
}
