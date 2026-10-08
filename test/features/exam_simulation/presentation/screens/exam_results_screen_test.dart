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

import '../../exam_simulation_test_harness.dart';

class MockExamRepository extends Mock implements ExamRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

final _attempt = ExamAttempt(
  attemptId: 'attempt-1',
  durationSeconds: 60,
  questions: [
    ExamQuestion(
      id: 'q1',
      text: 'Question 1',
      type: ExamQuestionType.multipleChoiceSingle,
      choices: const [
        ExamAnswerChoice(id: 'q1-a', text: 'Correct answer', order: 0),
        ExamAnswerChoice(id: 'q1-b', text: 'Wrong answer', order: 1),
      ],
    ),
  ],
);

const _result = ExamResult(
  attemptId: 'attempt-1',
  totalQuestions: 1,
  answered: 1,
  unanswered: 0,
  correct: 1,
  incorrect: 0,
  scorePercent: 100,
  durationTaken: Duration(seconds: 45),
  completionStatus: 'completed',
);

final _review = [
  const ExamReviewItem(
    questionId: 'q1',
    questionText: 'Question 1',
    choices: [
      ExamAnswerChoice(id: 'q1-a', text: 'Correct answer', order: 0),
      ExamAnswerChoice(id: 'q1-b', text: 'Wrong answer', order: 1),
    ],
    correctChoiceId: 'q1-a',
    selectedChoiceId: 'q1-a',
    isCorrect: true,
    wasFlagged: true,
    explanation: 'Because it is.',
  ),
];

Future<void> _completeExam(
  WidgetTester tester,
  MockExamRepository examRepository, {
  List<ExamReviewItem>? review,
  ExamResult result = _result,
}) async {
  useTallSurface(tester);
  final curriculumRepository = MockCurriculumRepository();
  when(() => curriculumRepository.getPrograms()).thenAnswer(
    (_) async => const Result.success([
      Program(id: 'program-cma', name: 'CMA', code: 'CMA'),
    ]),
  );
  when(() => curriculumRepository.getParts('program-cma')).thenAnswer(
    (_) async => const Result.success([
      Part(id: 'cma-part-1', programId: 'program-cma', name: 'Part 1'),
    ]),
  );
  when(() => examRepository.startExam(any()))
      .thenAnswer((_) async => Result.success(_attempt));
  when(
    () => examRepository.submitExam(
      attemptId: any(named: 'attemptId'),
      answers: any(named: 'answers'),
      flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
      timeTaken: any(named: 'timeTaken'),
    ),
  ).thenAnswer((_) async => Result.success(result));
  when(() => examRepository.getReview(any()))
      .thenAnswer((_) async => Result.success(review ?? _review));

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

  await tester.tap(find.text('Correct answer'));
  await tester.pump();
  // Straight from the question navigator — the second way to submit.
  await tester.tap(find.byTooltip('Question navigator'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit Exam'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
  await tester.pumpAndSettle();
}

/// The results screen grew taller (topic + question sections) — scroll a
/// button into view before tapping it.
Future<void> _tapResultsButton(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
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
    'shows the authoritative score and every metric from the backend result',
    (tester) async {
      final examRepository = MockExamRepository();
      await _completeExam(tester, examRepository);

      expect(find.text('100%'), findsOneWidget);
      // One question in 45s: total time used and average per question.
      expect(find.text('TOTAL TIME USED'), findsOneWidget);
      expect(find.text('AVG. TIME / QUESTION'), findsOneWidget);
      expect(find.text('00:45'), findsNWidgets(2));
      expect(find.text('Completed'), findsOneWidget);
    },
  );

  testWidgets('an unrecognized completion status is shown verbatim', (
    tester,
  ) async {
    final examRepository = MockExamRepository();
    await _completeExam(
      tester,
      examRepository,
      result: const ExamResult(
        attemptId: 'attempt-1',
        totalQuestions: 1,
        answered: 1,
        unanswered: 0,
        correct: 1,
        incorrect: 0,
        scorePercent: 100,
        durationTaken: Duration(seconds: 45),
        completionStatus: 'under_review',
      ),
    );

    expect(find.text('under_review'), findsOneWidget);
  });

  testWidgets(
    'navigating to Post-Exam Review shows the per-question review with flag state',
    (tester) async {
      final examRepository = MockExamRepository();
      await _completeExam(tester, examRepository);

      await _tapResultsButton(
        tester,
        find.widgetWithText(OutlinedButton, 'Review answers'),
      );

      expect(find.text('1. Question 1'), findsOneWidget);
      expect(find.text('Because it is.'), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
    },
  );

  testWidgets('Done resets the exam and leaves the exam-simulation flow', (
    tester,
  ) async {
    final examRepository = MockExamRepository();
    await _completeExam(tester, examRepository);

    await _tapResultsButton(tester, find.widgetWithText(FilledButton, 'Done'));

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
    'an empty review list is handled gracefully on the Post-Exam Review screen',
    (tester) async {
      final examRepository = MockExamRepository();
      await _completeExam(tester, examRepository, review: const []);

      await _tapResultsButton(
        tester,
        find.widgetWithText(OutlinedButton, 'Review answers'),
      );

      expect(
        find.text('Review is unavailable for this attempt.'),
        findsOneWidget,
      );
    },
  );
}
