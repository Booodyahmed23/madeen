import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/exam_simulation/presentation/widgets/exam_countdown_display.dart';

import '../../exam_fixtures.dart';
import '../../exam_simulation_test_harness.dart';

FakeExamQuestion _question(
  int n, {
  String topicId = 'topic-1',
  String topicName = 'Flexible Budget',
}) => FakeExamQuestion(
  id: 'q$n',
  text: 'Exam question number $n',
  choices: {'q$n-a': 'First option $n', 'q$n-b': 'Second option $n'},
  correctChoiceId: 'q$n-a',
  explanation: 'Explanation $n',
  topicId: topicId,
  topicName: topicName,
);

/// Q1 and Q2 on Flexible Budget, Q3 on Cost Behavior.
final _questions = [
  _question(1),
  _question(2),
  _question(3, topicId: 'topic-cost', topicName: 'Cost Behavior'),
];

late FakeExamRepository _exam;

Future<void> _startExam(
  WidgetTester tester, {
  int remainingSeconds = 90,
  Locale? locale,
  ThemeMode? themeMode,
  bool tall = true,
}) async {
  _exam = FakeExamRepository(
    questions: _questions,
    remainingSeconds: remainingSeconds,
    submittedAfter: const Duration(seconds: 60),
  );
  if (tall) {
    await startExamViaSetup(
      tester,
      _exam,
      locale: locale,
      themeMode: themeMode,
    );
    return;
  }
  // Small-surface layout check: same steps without forcing a tall view.
  await tester.pumpWidget(
    wrapExamScreen(
      examRepository: _exam,
      curriculumRepository: FakeCurriculumRepository(),
      locale: locale,
      themeMode: themeMode,
    ),
  );
  await tester.pumpAndSettle();
  final partPicker = find.byType(DropdownButtonFormField<Part>);
  await tester.ensureVisible(partPicker);
  await tester.tap(partPicker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Part 1').last);
  await tester.pumpAndSettle();
  final start = find.byType(FilledButton).last;
  await tester.ensureVisible(start);
  await tester.pumpAndSettle();
  await tester.tap(start);
  await tester.pumpAndSettle();
}

/// The countdown currently shown on the active screen, in seconds.
int _shownSeconds(WidgetTester tester) {
  final display = find.byType(ExamCountdownDisplay).first;
  final text = tester
      .widgetList<Text>(
        find.descendant(of: display, matching: find.byType(Text)),
      )
      .map((t) => t.data!)
      .firstWhere((d) => RegExp(r'^\d+:\d{2}(:\d{2})?$').hasMatch(d));
  final parts = text.split(':').map(int.parse).toList();
  return parts.fold(0, (sum, p) => sum * 60 + p);
}

Future<void> _openNavigator(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Question navigator'));
  await tester.pumpAndSettle();
}

Future<void> _submitFromNavigator(WidgetTester tester) async {
  await _openNavigator(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
  await tester.pumpAndSettle();
}

void main() {
  group('during the simulation', () {
    testWidgets(
      'exam rules: no pause, no topic, no feedback, number of total',
      (tester) async {
        await _startExam(tester);

        expect(find.text('Question 1 / 3'), findsOneWidget);
        expect(find.text('0 of 3 answered'), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsNothing);

        await tester.tap(find.text('Second option 1'));
        await tester.pumpAndSettle();

        expect(find.text('1 of 3 answered'), findsOneWidget);
        expect(find.textContaining('Flexible Budget'), findsNothing);
        expect(find.text('Correct'), findsNothing);
        expect(find.text('Incorrect'), findsNothing);
        expect(find.textContaining('Explanation'), findsNothing);
      },
    );

    testWidgets(
      'the navigator labels current/answered/unanswered/flagged and jumps',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _startExam(tester);
        await tester.tap(find.text('First option 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.outlined_flag));
        await tester.pumpAndSettle();

        await _openNavigator(tester);

        expect(find.text('Questions'), findsOneWidget);
        expect(find.bySemanticsLabel('Question 1, Answered'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Question 2, Current, Unanswered, Flagged'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Question 3, Unanswered'), findsOneWidget);
        for (final label in ['Current', 'Answered', 'Unanswered', 'Flagged']) {
          expect(find.text(label), findsWidgets);
        }

        await tester.tap(find.bySemanticsLabel('Question 3, Unanswered'));
        await tester.pumpAndSettle();
        expect(find.text('Exam question number 3'), findsOneWidget);
        expect(find.text('Question 3 / 3'), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets('a changed answer is saved again and is what counts', (
      tester,
    ) async {
      await _startExam(tester);

      await tester.tap(find.text('First option 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second option 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 answered'), findsOneWidget);
      expect(_exam.answers.map((a) => a.choiceId), ['q1-a', 'q1-b']);

      await _openNavigator(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
      await tester.pumpAndSettle();
      expect(
        find.text('You still have 2 unanswered questions.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'with every question answered the dialog asks for plain confirmation, '
      'and Cancel keeps the simulation running',
      (tester) async {
        await _startExam(tester);
        for (var n = 1; n <= 3; n++) {
          await tester.tap(find.text('First option $n'));
          await tester.pumpAndSettle();
          if (n < 3) {
            await tester.tap(find.widgetWithText(FilledButton, 'Next'));
            await tester.pumpAndSettle();
          }
        }

        await _openNavigator(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
        await tester.pumpAndSettle();

        expect(
          find.text('Are you sure you want to submit your simulation?'),
          findsOneWidget,
        );
        expect(find.textContaining('unanswered'), findsNothing);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(_exam.submitCalls, 0);
        expect(find.text('3 of 3 answered'), findsOneWidget);
      },
    );

    testWidgets(
      'the countdown keeps running across navigation and never counts up',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _startExam(tester);
        final start = _shownSeconds(tester);
        expect(start, inInclusiveRange(88, 90));

        await tester.pump(const Duration(seconds: 3));
        final afterWait = _shownSeconds(tester);
        expect(afterWait, start - 3);

        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pump(const Duration(seconds: 2));
        await _openNavigator(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.bySemanticsLabel('Question 3, Unanswered'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
        await tester.pump(const Duration(seconds: 1));

        final afterNavigation = _shownSeconds(tester);
        expect(afterNavigation, lessThanOrEqualTo(afterWait - 5));
        expect(afterNavigation, greaterThan(0));
        semantics.dispose();
      },
    );

    testWidgets('reaching zero submits and shows the timed-out result', (
      tester,
    ) async {
      await _startExam(tester, remainingSeconds: 3);
      _exam.submitStatus = 'EXPIRED';

      // No interaction at all: the clock alone ends the simulation.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(_exam.submitCalls, 1);
      expect(_exam.answers, isEmpty);
      expect(find.text('Timed out'), findsOneWidget);
    });
  });

  group('after submission', () {
    /// Q1 right, Q2 wrong, Q3 unanswered; submitted after 60 s.
    Future<void> submitAndOpenResults(WidgetTester tester) async {
      await _startExam(tester);
      await tester.tap(find.text('First option 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second option 2'));
      await tester.pumpAndSettle();
      await _submitFromNavigator(tester);
    }

    testWidgets('results show overall, per-topic, wrong and unanswered', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await submitAndOpenResults(tester);

      expect(find.text('OVERALL PERFORMANCE'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('00:20'), findsOneWidget, reason: '60s / 3 questions');
      expect(find.text('PERFORMANCE BY TOPIC'), findsOneWidget);
      expect(find.text('Flexible Budget'), findsOneWidget);
      expect(find.text('1 of 2 correct'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Cost Behavior'), findsOneWidget);
      expect(find.text('0 of 1 correct'), findsOneWidget);
      expect(find.text('WRONG ANSWERS'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 2, Answered'), findsOneWidget);
      expect(find.text('UNANSWERED QUESTIONS'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 3, Unanswered'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets(
      'a wrong question opens the review filtered to wrong answers, with the '
      'correct answer and topic revealed only now',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await submitAndOpenResults(tester);

        await tester.ensureVisible(
          find.bySemanticsLabel('Question 2, Answered'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Question 2, Answered'));
        await tester.pumpAndSettle();

        expect(find.text('Post-Exam Review'), findsOneWidget);
        expect(find.text('2. Exam question number 2'), findsOneWidget);
        expect(find.text('1. Exam question number 1'), findsNothing);
        expect(find.text('FLEXIBLE BUDGET'), findsOneWidget);
        expect(find.text('Explanation 2'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Unanswered'));
        await tester.pumpAndSettle();
        expect(find.text('3. Exam question number 3'), findsOneWidget);
        expect(find.text("You didn't answer this question."), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();
        for (var n = 1; n <= 3; n++) {
          expect(find.text('$n. Exam question number $n'), findsOneWidget);
        }
        semantics.dispose();
      },
    );
  });

  group('layout: Arabic RTL, dark, small phone, large text', () {
    testWidgets('navigator sheet and results render without overflow', (
      tester,
    ) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString().split('\n').first);
      addTearDown(() => FlutterError.onError = previous);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _startExam(
        tester,
        locale: const Locale('ar'),
        themeMode: ThemeMode.dark,
        tall: false,
      );
      final isRtl =
          Directionality.of(tester.element(find.byType(Scaffold).last)) ==
          TextDirection.rtl;

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.grid_view_outlined),
        ),
      );
      await tester.pumpAndSettle();
      final sheetShown = find.byType(BottomSheet).evaluate().length;

      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      final dialogShown = find.text('إرسال المحاكاة؟').evaluate().length;
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      FlutterError.onError = previous;

      expect(isRtl, isTrue);
      expect(sheetShown, 1);
      expect(dialogShown, 1);
      await tester.scrollUntilVisible(
        find.text('الأداء حسب الموضوع'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Flexible Budget'), findsOneWidget);
      expect(
        errors,
        isEmpty,
        reason: 'no overflow / layout errors in RTL dark at 320pt, 130% text',
      );
    });
  });
}
