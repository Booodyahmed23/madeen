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
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../exam_simulation_test_harness.dart';
import '../../../curriculum/curriculum_test_tree.dart';

class MockExamRepository extends Mock implements ExamRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

final _attempt = ExamAttempt(
  attemptId: 'attempt-1',
  durationSeconds: 90,
  questions: [
    ExamQuestion(
      id: 'q1',
      text: 'Under a flexible budget, which cost adjusts with volume?',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [
        ExamAnswerChoice(id: 'q1-a', text: 'Variable cost', order: 0),
        ExamAnswerChoice(id: 'q1-b', text: 'Fixed cost', order: 1),
      ],
    ),
    ExamQuestion(
      id: 'q2',
      text: 'Second question text',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [
        ExamAnswerChoice(id: 'q2-a', text: 'Choice A', order: 0),
        ExamAnswerChoice(id: 'q2-b', text: 'Choice B', order: 1),
      ],
    ),
  ],
);

/// Drives the real Setup screen to reach [ActiveExamScreen] with an actual
/// `ExamActive` state — there is no notifier-seeding shortcut, by design
/// (mirrors how Study Session's screen tests reach their Active screen).
Future<void> _startExamViaSetup(
  WidgetTester tester,
  MockExamRepository examRepository,
  MockCurriculumRepository curriculumRepository,
) async {
  useTallSurface(tester);
  when(() => curriculumRepository.getPrograms()).thenAnswer(
    (_) async =>
        const Result.success([Program(id: 'program-cma', name: 'CMA')]),
  );
  when(() => curriculumRepository.getProgramTree('program-cma')).thenAnswer(
    (_) async => Result.success(
      testCurriculumTree(
        program: const Program(id: 'program-cma', name: 'CMA'),
        parts: const [
          Part(id: 'cma-part-1', programId: 'program-cma', name: 'Part 1'),
        ],
      ),
    ),
  );

  await tester.pumpWidget(
    wrapExamScreen(
      examRepository: examRepository,
      curriculumRepository: curriculumRepository,
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
  await tester.tap(find.widgetWithText(FilledButton, 'Start exam'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ExamConfig(
        programId: 'x',
        programName: 'x',
        partId: 'x',
        partName: 'x',
        questionCount: 25,
        duration: Duration(minutes: 30),
      ),
    );
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(<String>{});
    registerFallbackValue(Duration.zero);
  });

  testWidgets(
    'shows the question, progress, and countdown — and no topic label anywhere',
    (tester) async {
      final examRepository = MockExamRepository();
      when(() => examRepository.startExam(any()))
          .thenAnswer((_) async => Result.success(_attempt));
      await _startExamViaSetup(
        tester,
        examRepository,
        MockCurriculumRepository(),
      );

      // The question, progress, and countdown are shown.
      expect(
        find.text('Under a flexible budget, which cost adjusts with volume?'),
        findsOneWidget,
      );
      expect(find.text('Question 1 / 2'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);

      // No curriculum/topic label appears anywhere on the active exam screen.
      expect(find.text('CMA'), findsNothing);
      expect(find.text('Part 1'), findsNothing);

      // No pause control exists (unlike Study Session).
      expect(find.byIcon(Icons.pause), findsNothing);
    },
  );

  testWidgets(
    'selecting a choice shows it selected and never reveals correctness',
    (tester) async {
      final examRepository = MockExamRepository();
      when(() => examRepository.startExam(any()))
          .thenAnswer((_) async => Result.success(_attempt));
      await _startExamViaSetup(
        tester,
        examRepository,
        MockCurriculumRepository(),
      );

      await tester.tap(find.text('Variable cost'));
      await tester.pump();

      expect(find.text('Correct'), findsNothing);
      expect(find.text('Incorrect'), findsNothing);
      // Selection is visually communicated (a check mark on the chosen tile).
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    },
  );

  testWidgets('flagging toggles the flag icon', (tester) async {
    final examRepository = MockExamRepository();
    when(() => examRepository.startExam(any()))
        .thenAnswer((_) async => Result.success(_attempt));
    await _startExamViaSetup(
      tester,
      examRepository,
      MockCurriculumRepository(),
    );

    expect(find.byIcon(Icons.flag), findsNothing);
    expect(find.byIcon(Icons.outlined_flag), findsOneWidget);

    await tester.tap(find.byIcon(Icons.outlined_flag));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.flag),
      ),
      findsOneWidget,
    );
    // The always-visible status line counts it too.
    expect(find.text('Flagged: 1'), findsOneWidget);
  });

  testWidgets(
    'next/previous move between questions without submitting the exam',
    (tester) async {
      final examRepository = MockExamRepository();
      when(() => examRepository.startExam(any()))
          .thenAnswer((_) async => Result.success(_attempt));
      await _startExamViaSetup(
        tester,
        examRepository,
        MockCurriculumRepository(),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Second question text'), findsOneWidget);
      verifyNever(
        () => examRepository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      );
    },
  );

  testWidgets('the last question shows "Review" instead of "Next"', (
    tester,
  ) async {
    final examRepository = MockExamRepository();
    when(() => examRepository.startExam(any()))
        .thenAnswer((_) async => Result.success(_attempt));
    await _startExamViaSetup(
      tester,
      examRepository,
      MockCurriculumRepository(),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Review'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
  });

  testWidgets('leaving the exam shows a confirmation dialog', (tester) async {
    final examRepository = MockExamRepository();
    when(() => examRepository.startExam(any()))
        .thenAnswer((_) async => Result.success(_attempt));
    await _startExamViaSetup(
      tester,
      examRepository,
      MockCurriculumRepository(),
    );

    final dynamic navigatorState = tester.state(find.byType(Navigator).first);
    navigatorState.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Leave this exam?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(
      find.text('Under a flexible budget, which cost adjusts with volume?'),
      findsOneWidget,
    );
  });
}
