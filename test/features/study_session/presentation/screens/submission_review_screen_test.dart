import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/entities/answer_choice.dart';
import 'package:mobile/features/study_session/domain/entities/question.dart';
import 'package:mobile/features/study_session/domain/entities/question_feedback.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/session_result.dart';
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
      text: 'Question 1',
      type: QuestionType.multipleChoiceSingle,
      choices: const [AnswerChoice(id: 'q1-a', text: 'A', order: 0)],
    ),
    Question(
      id: 'q2',
      text: 'Question 2',
      type: QuestionType.multipleChoiceSingle,
      choices: const [AnswerChoice(id: 'q2-a', text: 'A', order: 0)],
    ),
  ],
);

Future<void> _startSessionLeavingQ2Unanswered(
  WidgetTester tester,
  MockStudySessionRepository repository,
) async {
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
    'shows answered/unanswered counts and lets the student jump to an unanswered question',
    (tester) async {
      final repository = MockStudySessionRepository();
      when(
        () => repository.submitAnswer(
          sessionId: any(named: 'sessionId'),
          questionId: any(named: 'questionId'),
          selectedChoiceId: any(named: 'selectedChoiceId'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          QuestionFeedback(
            questionId: 'q1',
            isCorrect: true,
            correctChoiceId: 'q1-a',
          ),
        ),
      );
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
    when(
      () => repository.submitAnswer(
        sessionId: any(named: 'sessionId'),
        questionId: any(named: 'questionId'),
        selectedChoiceId: any(named: 'selectedChoiceId'),
      ),
    ).thenAnswer(
      (_) async => const Result.success(
        QuestionFeedback(
          questionId: 'q1',
          isCorrect: true,
          correctChoiceId: 'q1-a',
        ),
      ),
    );
    when(
      () => repository.submitSession(
        sessionId: any(named: 'sessionId'),
        answers: any(named: 'answers'),
        totalTime: any(named: 'totalTime'),
      ),
    ).thenAnswer(
      (_) async => const Result.success(
        SessionResult(
          sessionId: 'sess-1',
          totalQuestions: 2,
          answered: 1,
          unanswered: 1,
          correct: 1,
          incorrect: 0,
          scorePercent: 50,
          totalTime: Duration(seconds: 10),
          averageTimePerQuestion: Duration(seconds: 5),
        ),
      ),
    );
    when(() => repository.getReview(any()))
        .thenAnswer((_) async => const Result.success([]));

    await _startSessionLeavingQ2Unanswered(tester, repository);
    await tester.tap(find.byTooltip('Review & submit'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Submit session'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears; submission has NOT happened yet.
    expect(find.text('Submit this session?'), findsOneWidget);
    verifyNever(
      () => repository.submitSession(
        sessionId: any(named: 'sessionId'),
        answers: any(named: 'answers'),
        totalTime: any(named: 'totalTime'),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    verify(
      () => repository.submitSession(
        sessionId: any(named: 'sessionId'),
        answers: any(named: 'answers'),
        totalTime: any(named: 'totalTime'),
      ),
    ).called(1);
    // Landed on the Results screen.
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets(
    'a submission failure keeps the student on this screen with a retry path',
    (tester) async {
      final repository = MockStudySessionRepository();
      when(
        () => repository.submitAnswer(
          sessionId: any(named: 'sessionId'),
          questionId: any(named: 'questionId'),
          selectedChoiceId: any(named: 'selectedChoiceId'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          QuestionFeedback(
            questionId: 'q1',
            isCorrect: true,
            correctChoiceId: 'q1-a',
          ),
        ),
      );
      when(
        () => repository.submitSession(
          sessionId: any(named: 'sessionId'),
          answers: any(named: 'answers'),
          totalTime: any(named: 'totalTime'),
        ),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

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
