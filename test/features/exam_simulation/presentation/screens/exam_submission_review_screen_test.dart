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
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../exam_simulation_test_harness.dart';
import '../../../curriculum/curriculum_test_tree.dart';

class MockExamRepository extends Mock implements ExamRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

final _attempt = ExamAttempt(
  attemptId: 'attempt-1',
  durationSeconds: 120,
  questions: [
    ExamQuestion(
      id: 'q1',
      text: 'Question 1',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [ExamAnswerChoice(id: 'q1-a', text: 'A', order: 0)],
    ),
    ExamQuestion(
      id: 'q2',
      text: 'Question 2',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [ExamAnswerChoice(id: 'q2-a', text: 'A', order: 0)],
    ),
    ExamQuestion(
      id: 'q3',
      text: 'Question 3',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [ExamAnswerChoice(id: 'q3-a', text: 'A', order: 0)],
    ),
  ],
);

Future<void> _reachSubmissionReview(
  WidgetTester tester,
  MockExamRepository examRepository,
) async {
  useTallSurface(tester);
  final curriculumRepository = MockCurriculumRepository();
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
  when(() => examRepository.startExam(any()))
      .thenAnswer((_) async => Result.success(_attempt));

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

  // Answer question 1, flag question 2, leave question 3 unanswered.
  // This fixture's first choice is literally "A", which the MADEEN choice
  // tile's own letter anchor also shows — both are in the same tile.
  await tester.tap(find.text('A').first);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.outlined_flag));
  await tester.pump();

  // Through the question navigator sheet's Review action.
  await tester.tap(find.byTooltip('Question navigator'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Review'));
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
    'shows answered/unanswered/flagged counts and per-question status',
    (tester) async {
      final examRepository = MockExamRepository();
      await _reachSubmissionReview(tester, examRepository);

      expect(find.text('Answered: 1'), findsOneWidget);
      expect(find.text('Unanswered: 2'), findsOneWidget);
      expect(find.text('Flagged: 1'), findsOneWidget);
      expect(find.text('Answered'), findsOneWidget); // question 1's status
      expect(
        find.text('Flagged'),
        findsWidgets,
      ); // question 2's status + stat card
      expect(
        find.text('Unanswered'),
        findsWidgets,
      ); // question 3's status + stat card
    },
  );

  testWidgets('Review Unanswered jumps to the first unanswered question', (
    tester,
  ) async {
    final examRepository = MockExamRepository();
    await _reachSubmissionReview(tester, examRepository);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review Unanswered'));
    await tester.pumpAndSettle();

    expect(find.text('Question 3'), findsOneWidget);
  });

  testWidgets(
    'submitting requires explicit confirmation and warns about unanswered questions',
    (tester) async {
      final examRepository = MockExamRepository();
      when(
        () => examRepository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          ExamResult(
            attemptId: 'attempt-1',
            totalQuestions: 3,
            answered: 2,
            unanswered: 1,
            correct: 1,
            incorrect: 1,
            scorePercent: 33.3,
            durationTaken: Duration(seconds: 30),
            completionStatus: 'completed',
          ),
        ),
      );
      when(() => examRepository.getReview(any()))
          .thenAnswer((_) async => const Result.success([]));

      await _reachSubmissionReview(tester, examRepository);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
      await tester.pumpAndSettle();

      expect(find.text('Submit Simulation?'), findsOneWidget);
      expect(
        find.text('You still have 2 unanswered questions.'),
        findsOneWidget,
      );
      verifyNever(
        () => examRepository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      verify(
        () => examRepository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      ).called(1);
      expect(find.text('SCORE'), findsOneWidget);
    },
  );

  testWidgets('Cancel closes the confirmation without submitting', (
    tester,
  ) async {
    final examRepository = MockExamRepository();
    await _reachSubmissionReview(tester, examRepository);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Simulation?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => examRepository.submitExam(
        attemptId: any(named: 'attemptId'),
        answers: any(named: 'answers'),
        flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
        timeTaken: any(named: 'timeTaken'),
      ),
    );
    expect(find.text('Exam Review'), findsOneWidget);
  });
}
