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
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

// English exam content (ending in punctuation) shown inside the Arabic UI —
// the mixed-language case: laid out RTL, the trailing "?" / "." would jump
// to the wrong end of the line.
const _questionText = 'Which costs vary with production volume?';
const _explanation = 'Variable costs change in total with output.';

final _bundle = StudySessionBundle(
  sessionId: 'sess-1',
  questions: [
    Question(
      id: 'q1',
      text: _questionText,
      type: QuestionType.multipleChoiceSingle,
      choices: const [
        AnswerChoice(id: 'q1-a', text: 'Variable costs', order: 0),
        AnswerChoice(id: 'q1-b', text: 'Fixed costs', order: 1),
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

const _review = [
  QuestionReviewItem(
    questionId: 'q1',
    questionText: _questionText,
    choices: [
      AnswerChoice(id: 'q1-a', text: 'Variable costs', order: 0),
      AnswerChoice(id: 'q1-b', text: 'Fixed costs', order: 1),
    ],
    correctChoiceId: 'q1-a',
    selectedChoiceId: 'q1-a',
    isCorrect: true,
    explanation: _explanation,
  ),
];

void _stubRepository(MockStudySessionRepository repository) {
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
        explanation: _explanation,
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
      .thenAnswer((_) async => const Result.success(_review));
}

Text _textWidget(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

void _expectLtrContentAlignedTo(Text text, TextAlign align) {
  expect(text.textDirection, TextDirection.ltr);
  expect(text.textAlign, align);
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

  testWidgets('Arabic UI: English question, explanation and review keep LTR '
      'punctuation while aligned to the RTL start edge', (tester) async {
    const ar = Locale('ar');
    final l10n = lookupAppLocalizations(ar);
    final repository = MockStudySessionRepository();
    _stubRepository(repository);
    useTallSurface(tester);

    await tester.pumpWidget(
      wrapStudySessionScreen(repository: repository, locale: ar),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.studySessionSetupStartButton),
    );
    await tester.pumpAndSettle();

    // Active session — the question stem.
    _expectLtrContentAlignedTo(
      _textWidget(tester, _questionText),
      TextAlign.right,
    );

    await tester.tap(find.text('Variable costs'));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.studySessionSubmitAnswerButton),
    );
    await tester.pumpAndSettle();

    // Immediate feedback — the explanation.
    _expectLtrContentAlignedTo(
      _textWidget(tester, _explanation),
      TextAlign.right,
    );

    await tester.tap(find.byTooltip(l10n.studySessionReviewAndSubmitButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.studySessionSubmitSessionButton),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.studySessionSubmitConfirmConfirm),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, l10n.studySessionResultsReviewButton),
    );
    await tester.pumpAndSettle();

    // Post-session review — numbered stem, chosen/correct answer, and
    // explanation.
    _expectLtrContentAlignedTo(
      _textWidget(tester, '1. $_questionText'),
      TextAlign.right,
    );
    for (final text in tester.widgetList<Text>(find.text('Variable costs'))) {
      _expectLtrContentAlignedTo(text, TextAlign.right);
    }
    _expectLtrContentAlignedTo(
      _textWidget(tester, _explanation),
      TextAlign.right,
    );
  });

  testWidgets('English UI: question content stays plain LTR', (tester) async {
    final repository = MockStudySessionRepository();
    _stubRepository(repository);
    useTallSurface(tester);

    await tester.pumpWidget(wrapStudySessionScreen(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
    await tester.pumpAndSettle();

    _expectLtrContentAlignedTo(
      _textWidget(tester, _questionText),
      TextAlign.left,
    );
  });

  testWidgets('Arabic content in the Arabic UI stays RTL', (tester) async {
    const ar = Locale('ar');
    final l10n = lookupAppLocalizations(ar);
    const arabicQuestion = 'ما هي التكاليف المتغيرة؟';
    final repository = MockStudySessionRepository();
    when(() => repository.startSession(any())).thenAnswer(
      (_) async => Result.success(
        StudySessionBundle(
          sessionId: 'sess-1',
          questions: [
            Question(
              id: 'q1',
              text: arabicQuestion,
              type: QuestionType.multipleChoiceSingle,
              choices: const [
                AnswerChoice(id: 'q1-a', text: 'أ', order: 0),
                AnswerChoice(id: 'q1-b', text: 'ب', order: 1),
              ],
            ),
          ],
        ),
      ),
    );
    useTallSurface(tester);

    await tester.pumpWidget(
      wrapStudySessionScreen(repository: repository, locale: ar),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.studySessionSetupStartButton),
    );
    await tester.pumpAndSettle();

    final text = _textWidget(tester, arabicQuestion);
    expect(text.textDirection, TextDirection.rtl);
    expect(text.textAlign, TextAlign.right);
  });
}
