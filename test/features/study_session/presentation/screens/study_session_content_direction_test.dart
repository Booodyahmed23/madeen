import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';
import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

// English exam content (ending in punctuation) shown inside the Arabic UI —
// the mixed-language case: laid out RTL, the trailing "?" / "." would jump
// to the wrong end of the line.
const _questionText = 'Which costs vary with production volume?';
const _explanation = 'Variable costs change in total with output.';

const _question = FakeQuestion(
  id: 'q1',
  text: _questionText,
  choices: {'q1-a': 'Variable costs', 'q1-b': 'Fixed costs'},
  correctChoiceId: 'q1-a',
  explanation: _explanation,
);

void _stubRepository(MockStudySessionRepository repository) {
  final answered = _question.answer('q1-a', addSeconds: 30);
  when(() => repository.startSession(any())).thenAnswer(
    (_) async => Result.success(fakeSession(questions: const [_question])),
  );
  when(
    () => repository.answerQuestion(
      sessionId: any(named: 'sessionId'),
      questionId: any(named: 'questionId'),
      choiceId: any(named: 'choiceId'),
      timeSpentSeconds: any(named: 'timeSpentSeconds'),
    ),
  ).thenAnswer((_) async => Result.success(fakeSession(questions: [answered])));
  when(() => repository.completeSession(any())).thenAnswer(
    (_) async =>
        Result.success(fakeSession(status: 'COMPLETED', questions: [answered])),
  );
}

Text _textWidget(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

void _expectLtrContentAlignedTo(Text text, TextAlign align) {
  expect(text.textDirection, TextDirection.ltr);
  expect(text.textAlign, align);
}

void main() {
  setUpAll(() => registerFallbackValue(testSessionConfig));

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
        fakeSession(
          questions: const [
            FakeQuestion(
              id: 'q1',
              text: arabicQuestion,
              choices: {'q1-a': 'أ', 'q1-b': 'ب'},
              correctChoiceId: 'q1-a',
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
