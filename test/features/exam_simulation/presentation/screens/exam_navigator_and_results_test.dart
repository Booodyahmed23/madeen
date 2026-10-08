import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_result.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_review_item.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/exam_simulation/presentation/widgets/exam_countdown_display.dart';

import '../../exam_simulation_test_harness.dart';
import '../../../curriculum/curriculum_test_tree.dart';

class MockExamRepository extends Mock implements ExamRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

ExamQuestion _question(int n) => ExamQuestion(
  id: 'q$n',
  text: 'Exam question number $n',
  type: ExamQuestionType.multipleChoiceSingle,
  choices: [
    ExamAnswerChoice(id: 'q$n-a', text: 'First option $n', order: 0),
    ExamAnswerChoice(id: 'q$n-b', text: 'Second option $n', order: 1),
  ],
);

ExamAttempt _attempt({int durationSeconds = 90}) => ExamAttempt(
  attemptId: 'attempt-1',
  durationSeconds: durationSeconds,
  questions: [_question(1), _question(2), _question(3)],
);

ExamReviewItem _reviewItem(
  int n, {
  required String? selected,
  required String topicId,
  required String topicName,
}) => ExamReviewItem(
  questionId: 'q$n',
  questionText: 'Question $n',
  choices: [
    ExamAnswerChoice(id: 'q$n-a', text: 'First option $n', order: 0),
    ExamAnswerChoice(id: 'q$n-b', text: 'Second option $n', order: 1),
  ],
  correctChoiceId: 'q$n-a',
  selectedChoiceId: selected,
  isCorrect: selected == 'q$n-a',
  wasFlagged: false,
  explanation: 'Explanation $n',
  topicId: topicId,
  topicName: topicName,
);

/// Q1 right and Q2 wrong (both Flexible Budget), Q3 unanswered (Cost
/// Behavior).
final _review = [
  _reviewItem(
    1,
    selected: 'q1-a',
    topicId: 'topic-flexible-budget',
    topicName: 'Flexible Budget',
  ),
  _reviewItem(
    2,
    selected: 'q2-b',
    topicId: 'topic-flexible-budget',
    topicName: 'Flexible Budget',
  ),
  _reviewItem(
    3,
    selected: null,
    topicId: 'topic-cost-behavior',
    topicName: 'Cost Behavior',
  ),
];

const _result = ExamResult(
  attemptId: 'attempt-1',
  totalQuestions: 3,
  answered: 2,
  unanswered: 1,
  correct: 1,
  incorrect: 1,
  scorePercent: 100 / 3,
  durationTaken: Duration(seconds: 60),
  completionStatus: 'completed',
);

late MockExamRepository _exam;

Future<void> _startExam(
  WidgetTester tester, {
  int durationSeconds = 90,
  ExamResult result = _result,
  Locale? locale,
  ThemeMode? themeMode,
  bool tall = true,
}) async {
  if (tall) useTallSurface(tester);
  final curriculum = MockCurriculumRepository();
  when(() => curriculum.getPrograms()).thenAnswer(
    (_) async =>
        const Result.success([Program(id: 'program-cma', name: 'CMA')]),
  );
  when(() => curriculum.getProgramTree('program-cma')).thenAnswer(
    (_) async => Result.success(
      testCurriculumTree(
        program: const Program(id: 'program-cma', name: 'CMA'),
        parts: const [
          Part(id: 'cma-part-1', programId: 'program-cma', name: 'Part 1'),
        ],
      ),
    ),
  );
  when(() => _exam.startExam(any())).thenAnswer(
    (_) async => Result.success(_attempt(durationSeconds: durationSeconds)),
  );
  when(
    () => _exam.submitExam(
      attemptId: any(named: 'attemptId'),
      answers: any(named: 'answers'),
      flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
      timeTaken: any(named: 'timeTaken'),
    ),
  ).thenAnswer((_) async => Result.success(result));
  when(() => _exam.getReview(any()))
      .thenAnswer((_) async => Result.success(_review));

  await tester.pumpWidget(
    wrapExamScreen(
      examRepository: _exam,
      curriculumRepository: curriculum,
      locale: locale,
      themeMode: themeMode,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<Program>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CMA').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<Part>));
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

Map<String, String?> _submittedAnswers() =>
    verify(
          () => _exam.submitExam(
            attemptId: any(named: 'attemptId'),
            answers: captureAny(named: 'answers'),
            flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
            timeTaken: any(named: 'timeTaken'),
          ),
        ).captured.single
        as Map<String, String?>;

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ExamConfig(
        programId: 'x',
        programName: 'x',
        partId: 'x',
        partName: 'x',
        questionCount: 10,
        duration: Duration(minutes: 15),
      ),
    );
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(<String>{});
    registerFallbackValue(Duration.zero);
  });

  setUp(() => _exam = MockExamRepository());

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
        await tester.pump();

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
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.outlined_flag));
        await tester.pump();

        await _openNavigator(tester);
        expect(find.text('QUESTIONS'), findsNothing); // title, not an eyebrow
        expect(find.text('Questions'), findsOneWidget);
        expect(find.bySemanticsLabel('Question 1, Answered'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Question 2, Current, Unanswered, Flagged'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Question 3, Unanswered'), findsOneWidget);
        // The legend explains every state.
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

    testWidgets(
      'an answer can be changed, and navigating back keeps it, before submit',
      (tester) async {
        await _startExam(tester);

        await tester.tap(find.text('First option 1'));
        await tester.pump();
        await tester.tap(find.text('Second option 1'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
        await tester.pumpAndSettle();
        expect(find.text('Exam question number 1'), findsOneWidget);
        expect(find.text('1 of 3 answered'), findsOneWidget);

        await _openNavigator(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
        await tester.pumpAndSettle();

        expect(find.text('Submit Simulation?'), findsOneWidget);
        expect(
          find.text('You still have 2 unanswered questions.'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
        await tester.pumpAndSettle();

        final answers = _submittedAnswers();
        expect(answers['q1'], 'q1-b', reason: 'the changed answer counts');
        expect(answers['q2'], isNull);
        expect(answers['q3'], isNull);
      },
    );

    testWidgets(
      'with every question answered the dialog asks for plain confirmation, '
      'and Cancel keeps the simulation running',
      (tester) async {
        await _startExam(tester);
        for (var n = 1; n <= 3; n++) {
          await tester.tap(find.text('First option $n'));
          await tester.pump();
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
        verifyNever(
          () => _exam.submitExam(
            attemptId: any(named: 'attemptId'),
            answers: any(named: 'answers'),
            flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
            timeTaken: any(named: 'timeTaken'),
          ),
        );
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

        // Next, the navigator sheet, a jump, back again — the clock never
        // restarts or pauses.
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

    testWidgets('reaching zero auto-submits and shows the timed-out result', (
      tester,
    ) async {
      await _startExam(
        tester,
        durationSeconds: 3,
        result: const ExamResult(
          attemptId: 'attempt-1',
          totalQuestions: 3,
          answered: 0,
          unanswered: 3,
          correct: 0,
          incorrect: 0,
          scorePercent: 0,
          durationTaken: Duration(seconds: 3),
          completionStatus: 'timed_out',
        ),
      );

      // No interaction at all: the clock alone ends the simulation.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Timed out'), findsOneWidget);
      final submitted = verify(
        () => _exam.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: captureAny(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: captureAny(named: 'timeTaken'),
        ),
      ).captured;
      expect(
        (submitted[0] as Map<String, String?>).values.every((a) => a == null),
        isTrue,
      );
      expect(submitted[1], const Duration(seconds: 3));
    });
  });

  group('after submission', () {
    Future<void> submitAndOpenResults(WidgetTester tester) async {
      await _startExam(tester);
      await tester.tap(find.text('First option 1'));
      await tester.pump();
      await _openNavigator(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
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
      'correct answer revealed only now',
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
        expect(find.text('2. Question 2'), findsOneWidget);
        expect(find.text('1. Question 1'), findsNothing);
        expect(find.text('3. Question 3'), findsNothing);
        // The topic is revealed after submission.
        expect(find.text('FLEXIBLE BUDGET'), findsOneWidget);
        expect(find.text('Explanation 2'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Unanswered'));
        await tester.pumpAndSettle();
        expect(find.text('3. Question 3'), findsOneWidget);
        expect(find.text("You didn't answer this question."), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();
        for (var n = 1; n <= 3; n++) {
          expect(find.text('$n. Question $n'), findsOneWidget);
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

      // Language-independent: the navigator's app-bar icon.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.grid_view_outlined),
        ),
      );
      await tester.pumpAndSettle();
      final sheetShown = find.byType(BottomSheet).evaluate().length;
      // Submit from the sheet, through the (Arabic) confirmation.
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
      // Back up to the per-topic breakdown (built lazily below the fold).
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
