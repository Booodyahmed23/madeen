import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/entities/sub_unit.dart';
import 'package:mobile/features/curriculum/domain/entities/unit.dart';
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
  });

  late MockCurriculumRepository curriculumRepository;

  setUp(() {
    curriculumRepository = MockCurriculumRepository();
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
  });

  testWidgets(
    'lets the student pick a program, part and question count — the time '
    'limit follows from the count',
    (tester) async {
      useTallSurface(tester);
      final examRepository = MockExamRepository();

      await tester.pumpWidget(
        wrapExamScreen(
          examRepository: examRepository,
          curriculumRepository: curriculumRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exam Simulation Setup'), findsOneWidget);
      // Default: 10 questions, 15 minutes — no separate duration picker.
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10'))
            .selected,
        isTrue,
      );
      expect(find.text('Time limit'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      for (final (count, limit) in [
        ('20', '30 min'),
        ('50', '1 h'),
        ('80', '2 h'),
      ]) {
        await tester.tap(find.widgetWithText(ChoiceChip, count));
        await tester.pumpAndSettle();
        expect(find.text(limit), findsOneWidget, reason: '$count questions');
      }
      // The exam rules are spelled out before the clock starts.
      expect(find.text('EXAM CONDITIONS'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<Program>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CMA').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<Part>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part 1').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start exam'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'the Start button stays disabled until a program and part are chosen',
    (tester) async {
      useTallSurface(tester);
      final examRepository = MockExamRepository();

      await tester.pumpWidget(
        wrapExamScreen(
          examRepository: examRepository,
          curriculumRepository: curriculumRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start exam'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'starting an exam sends the selected configuration to the repository',
    (tester) async {
      useTallSurface(tester);
      final examRepository = MockExamRepository();
      final completer = Completer<Result<ExamAttempt>>();
      when(() => examRepository.startExam(any()))
          .thenAnswer((_) => completer.future);

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

      await tester.tap(find.widgetWithText(ChoiceChip, '50'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Random'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start exam'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      final captured = verify(() => examRepository.startExam(captureAny()))
          .captured;
      final config = captured.single as ExamConfig;
      expect(config.programId, 'program-cma');
      expect(config.partId, 'cma-part-1');
      expect(config.questionCount, 50);
      expect(config.duration, const Duration(hours: 1));
      expect(config.questionOrder, ExamQuestionOrder.random);
      // No unit picked: the whole Part.
      expect(config.unitId, isNull);
      expect(config.subUnitId, isNull);

      completer.complete(
        const Result.success(
          ExamAttempt(
            attemptId: 'attempt-1',
            durationSeconds: 3600,
            questions: [
              ExamQuestion(
                id: 'q1',
                text: 'Sample exam question',
                type: ExamQuestionType.multipleChoiceSingle,
                choices: [ExamAnswerChoice(id: 'q1-a', text: 'A')],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sample exam question'), findsOneWidget);
    },
  );

  testWidgets('shows a localized error message when starting an exam fails', (
    tester,
  ) async {
    useTallSurface(tester);
    final examRepository = MockExamRepository();
    when(() => examRepository.startExam(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

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

    expect(find.text('Network error. Please try again.'), findsOneWidget);
  });

  testWidgets(
    'shows the sample-data banner when the exam simulation API is unavailable',
    (tester) async {
      useTallSurface(tester);
      final examRepository = MockExamRepository();

      await tester.pumpWidget(
        wrapExamScreen(
          examRepository: examRepository,
          curriculumRepository: curriculumRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Showing a sample exam — the Exam Simulation service isn't connected yet.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Unit and Sub-unit optionally narrow the scope and are sent with the '
    'configuration',
    (tester) async {
      useTallSurface(tester);
      when(() => curriculumRepository.getProgramTree('program-cma')).thenAnswer(
        (_) async => Result.success(
          testCurriculumTree(
            program: const Program(id: 'program-cma', name: 'CMA'),
            parts: const [
              Part(id: 'cma-part-1', programId: 'program-cma', name: 'Part 1'),
            ],
            units: const [
              Unit(
                id: 'unit-financial-planning',
                partId: 'cma-part-1',
                name: 'Financial Planning',
              ),
            ],
            subUnits: const [
              SubUnit(
                id: 'subunit-budgeting',
                unitId: 'unit-financial-planning',
                name: 'Budgeting',
              ),
            ],
          ),
        ),
      );
      final examRepository = MockExamRepository();
      when(() => examRepository.startExam(any()))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await tester.pumpWidget(
        wrapExamScreen(
          examRepository: examRepository,
          curriculumRepository: curriculumRepository,
        ),
      );
      await tester.pumpAndSettle();

      // No Unit picker until a Part is chosen.
      expect(find.text('UNIT'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<Program>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CMA').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Part>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part 1').last);
      await tester.pumpAndSettle();

      expect(find.text('UNIT'), findsOneWidget);
      expect(find.text('All units'), findsOneWidget);
      expect(find.text('SUB-UNIT'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<Unit?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Financial Planning').last);
      await tester.pumpAndSettle();

      expect(find.text('SUB-UNIT'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<SubUnit?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budgeting').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start exam'));
      await tester.pumpAndSettle();

      final config =
          verify(() => examRepository.startExam(captureAny())).captured.single
              as ExamConfig;
      expect(config.unitId, 'unit-financial-planning');
      expect(config.unitName, 'Financial Planning');
      expect(config.subUnitId, 'subunit-budgeting');
      expect(config.subUnitName, 'Budgeting');
      expect(config.questionOrder, ExamQuestionOrder.original);
    },
  );
}
