import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/entities/answer_choice.dart';
import 'package:mobile/features/study_session/domain/entities/question.dart';
import 'package:mobile/features/study_session/domain/entities/question_feedback.dart';
import 'package:mobile/features/study_session/domain/entities/question_review_item.dart';
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
      choices: const [
        AnswerChoice(id: 'q1-a', text: 'Correct answer', order: 0),
        AnswerChoice(id: 'q1-b', text: 'Wrong answer', order: 1),
      ],
    ),
  ],
);

const _result = SessionResult(
  sessionId: 'sess-1',
  totalQuestions: 1,
  answered: 1,
  unanswered: 0,
  correct: 1,
  incorrect: 0,
  scorePercent: 100,
  totalTime: Duration(seconds: 30),
  averageTimePerQuestion: Duration(seconds: 30),
);

final _review = [
  const QuestionReviewItem(
    questionId: 'q1',
    questionText: 'Question 1',
    choices: [
      AnswerChoice(id: 'q1-a', text: 'Correct answer', order: 0),
      AnswerChoice(id: 'q1-b', text: 'Wrong answer', order: 1),
    ],
    correctChoiceId: 'q1-a',
    selectedChoiceId: 'q1-a',
    isCorrect: true,
    explanation: 'Because it is.',
  ),
];

Future<void> _completeSession(
  WidgetTester tester,
  MockStudySessionRepository repository, {
  List<QuestionReviewItem>? review,
}) async {
  useTallSurface(tester);
  when(() => repository.startSession(any()))
      .thenAnswer((_) async => Result.success(_bundle));
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
  ).thenAnswer((_) async => const Result.success(_result));
  when(() => repository.getReview(any()))
      .thenAnswer((_) async => Result.success(review ?? _review));

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
    'shows the authoritative score and every metric from the backend result',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _completeSession(tester, repository);

      expect(find.text('100%'), findsOneWidget);
      expect(
        find.text('1'),
        findsWidgets,
      ); // totalQuestions/answered/correct all 1
      expect(find.text('0'), findsWidgets); // unanswered/incorrect
      expect(find.text('00:30'), findsWidgets); // total time + average time
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

  testWidgets(
    'an empty review list is handled gracefully on the Review screen',
    (tester) async {
      final repository = MockStudySessionRepository();
      await _completeSession(tester, repository, review: const []);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Review answers'));
      await tester.pumpAndSettle();

      expect(
        find.text('Review is unavailable for this session.'),
        findsOneWidget,
      );
    },
  );
}
