import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/paginated.dart';
import 'package:mobile/features/curriculum/domain/entities/curriculum_tree.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/entities/sub_unit.dart';
import 'package:mobile/features/curriculum/domain/entities/topic.dart';
import 'package:mobile/features/curriculum/domain/entities/unit.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_attempt_model.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';

import '../curriculum/curriculum_test_tree.dart';
import 'exam_simulation_test_harness.dart';

/// One question for [fakeAttempt]: [choices] maps choice id → text.
class FakeExamQuestion {
  const FakeExamQuestion({
    required this.id,
    required this.text,
    required this.choices,
    required this.correctChoiceId,
    this.selectedChoiceId,
    this.flagged = false,
    this.topicId = 'topic-1',
    this.topicName = 'Flexible Budget',
    this.explanation,
  });

  final String id;
  final String text;
  final Map<String, String> choices;
  final String correctChoiceId;
  final String? selectedChoiceId;
  final bool flagged;
  final String topicId;
  final String topicName;
  final String? explanation;

  FakeExamQuestion copyWith({String? selectedChoiceId, bool? flagged}) =>
      FakeExamQuestion(
        id: id,
        text: text,
        choices: choices,
        correctChoiceId: correctChoiceId,
        selectedChoiceId: selectedChoiceId ?? this.selectedChoiceId,
        flagged: flagged ?? this.flagged,
        topicId: topicId,
        topicName: topicName,
        explanation: explanation,
      );

  FakeExamQuestion answer(String choiceId) =>
      copyWith(selectedChoiceId: choiceId);
}

const eq1 = FakeExamQuestion(
  id: 'eq1',
  text: 'What is a flexible budget?',
  choices: {'eq1-a': 'One that adjusts to volume', 'eq1-b': 'A fixed plan'},
  correctChoiceId: 'eq1-a',
  explanation: 'It flexes with activity.',
);

const eq2 = FakeExamQuestion(
  id: 'eq2',
  text: 'What is a master budget?',
  choices: {'eq2-a': 'The overall plan', 'eq2-b': 'A cost report'},
  correctChoiceId: 'eq2-a',
  topicId: 'topic-2',
  topicName: 'Master Budget',
);

final examStartedAt = DateTime.utc(2026, 10, 8, 10);

/// An exam attempt exactly as the API returns it, parsed by the app's own
/// parser. [status] `SUBMITTED`/`EXPIRED` reveals every question.
ExamAttempt fakeAttempt({
  String id = 'attempt-1',
  String status = 'IN_PROGRESS',
  int durationMinutes = 15,
  int? remainingSeconds,
  List<FakeExamQuestion> questions = const [eq1, eq2],
  Duration submittedAfter = const Duration(minutes: 5),
}) => examAttemptFromJson(
  fakeAttemptJson(
    id: id,
    status: status,
    durationMinutes: durationMinutes,
    remainingSeconds: remainingSeconds,
    questions: questions,
    submittedAfter: submittedAfter,
  ),
);

Map<String, dynamic> fakeAttemptJson({
  String id = 'attempt-1',
  String status = 'IN_PROGRESS',
  int durationMinutes = 15,
  int? remainingSeconds,
  List<FakeExamQuestion> questions = const [eq1, eq2],
  Duration submittedAfter = const Duration(minutes: 5),
}) {
  final ended = status != 'IN_PROGRESS';
  final answered = questions.where((q) => q.selectedChoiceId != null);
  final correct = answered
      .where((q) => q.selectedChoiceId == q.correctChoiceId)
      .length;
  final expiresAt = examStartedAt.add(Duration(minutes: durationMinutes));
  final submittedAt = status == 'EXPIRED'
      ? expiresAt
      : examStartedAt.add(submittedAfter);
  return {
    'id': id,
    'userId': 'user-1',
    'status': status,
    'durationMinutes': durationMinutes,
    'topicIds': {for (final q in questions) q.topicId}.toList(),
    'difficulty': null,
    'requestedCount': questions.length,
    'startedAt': examStartedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'submittedAt': ended ? submittedAt.toIso8601String() : null,
    'createdAt': examStartedAt.toIso8601String(),
    'updatedAt': examStartedAt.toIso8601String(),
    'remainingSeconds': ended ? 0 : remainingSeconds ?? durationMinutes * 60,
    'progress': {
      'total': questions.length,
      'answered': answered.length,
      'flagged': questions.where((q) => q.flagged).length,
    },
    'score': ended
        ? {
            'correct': correct,
            'incorrect': answered.length - correct,
            'unanswered': questions.length - answered.length,
          }
        : null,
    'questions': [
      for (final (index, q) in questions.indexed)
        {
          'id': 'aq-$index',
          'questionId': q.id,
          'order': index,
          'isFlagged': q.flagged,
          'answeredAt': q.selectedChoiceId == null
              ? null
              : examStartedAt
                    .add(Duration(minutes: index + 1))
                    .toIso8601String(),
          'timeSpentSeconds': q.selectedChoiceId == null ? 0 : 10,
          'selectedChoiceId': q.selectedChoiceId,
          'isCorrect': ended && q.selectedChoiceId != null
              ? q.selectedChoiceId == q.correctChoiceId
              : null,
          'question': {
            'id': q.id,
            'text': q.text,
            'topic': {
              'id': q.topicId,
              'name': q.topicName,
              'description': null,
            },
            'code': index + 1,
            'losCode': null,
            'difficulty': 'MEDIUM',
            'explanation': ended ? q.explanation : null,
          },
          'choices': [
            for (final entry in q.choices.entries)
              {
                'id': entry.key,
                'text': entry.value,
                if (ended) 'isCorrect': entry.key == q.correctChoiceId,
              },
          ],
        },
    ],
  };
}

const testExamConfig = ExamConfig(
  programId: 'program-cma',
  programName: 'CMA',
  partId: 'cma-part-1',
  partName: 'Part 1',
  questionCount: 10,
  duration: Duration(minutes: 15),
  topicIds: ['topic-1', 'topic-2'],
);

/// A server-like [ExamRepository] over [FakeExamQuestion]s: start returns
/// them, answers and flags update them, submit ends the attempt. Records
/// what the app asked for; [submitFailure] / [answerFailure] make those
/// calls fail.
class FakeExamRepository implements ExamRepository {
  FakeExamRepository({
    List<FakeExamQuestion> questions = const [eq1, eq2],
    this.durationMinutes = 15,
    this.remainingSeconds,
    this.submitStatus = 'SUBMITTED',
    this.submittedAfter = const Duration(minutes: 5),
  }) : _questions = [...questions];

  /// Time between `startedAt` and `submittedAt` in the submitted attempt.
  final Duration submittedAfter;

  List<FakeExamQuestion> _questions;
  final int durationMinutes;
  final int? remainingSeconds;

  /// `SUBMITTED`, or `EXPIRED` to act as if time ran out server-side.
  String submitStatus;
  AppFailure? startFailure;
  AppFailure? submitFailure;
  AppFailure? answerFailure;
  String _status = 'IN_PROGRESS';

  final startedWith = <ExamConfig>[];
  final answers = <({String questionId, String choiceId})>[];
  final flags = <({String questionId, bool flagged})>[];
  var submitCalls = 0;

  ExamAttempt get _attempt => fakeAttempt(
    status: _status,
    durationMinutes: durationMinutes,
    remainingSeconds: remainingSeconds,
    questions: _questions,
    submittedAfter: submittedAfter,
  );

  @override
  Future<Result<ExamAttempt>> startExam(ExamConfig config) async {
    startedWith.add(config);
    final failure = startFailure;
    if (failure != null) return Result.failure(failure);
    return Result.success(_attempt);
  }

  @override
  Future<Result<ExamAttempt>> getAttempt(String attemptId) async =>
      Result.success(_attempt);

  @override
  Future<Result<Paginated<ExamAttemptSummary>>> listAttempts({
    int page = 1,
    int limit = 20,
  }) async => const Result.success(
    Paginated(items: [], page: 1, limit: 20, total: 0, totalPages: 0),
  );

  @override
  Future<Result<ExamAttempt>> answerQuestion({
    required String attemptId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) async {
    answers.add((questionId: questionId, choiceId: choiceId));
    final failure = answerFailure;
    if (failure != null) return Result.failure(failure);
    _questions = [
      for (final q in _questions) q.id == questionId ? q.answer(choiceId) : q,
    ];
    return Result.success(_attempt);
  }

  @override
  Future<Result<ExamAttempt>> flagQuestion({
    required String attemptId,
    required String questionId,
    required bool flagged,
  }) async {
    flags.add((questionId: questionId, flagged: flagged));
    _questions = [
      for (final q in _questions)
        q.id == questionId ? q.copyWith(flagged: flagged) : q,
    ];
    return Result.success(_attempt);
  }

  @override
  Future<Result<ExamAttempt>> submitExam(String attemptId) async {
    submitCalls++;
    final failure = submitFailure;
    if (failure != null) return Result.failure(failure);
    _status = submitStatus;
    return Result.success(_attempt);
  }
}

/// A CMA tree whose Part 1 holds [eq1]'s and [eq2]'s topics, so Exam Setup
/// can resolve the selection to topic ids.
CurriculumTree examCurriculumTree() => testCurriculumTree(
  program: const Program(id: 'program-cma', name: 'CMA'),
  parts: const [
    Part(id: 'cma-part-1', programId: 'program-cma', name: 'Part 1'),
    Part(id: 'cma-part-2', programId: 'program-cma', name: 'Part 2'),
  ],
  units: const [
    Unit(
      id: 'unit-financial-planning',
      partId: 'cma-part-1',
      name: 'Financial Planning',
    ),
    Unit(id: 'unit-2', partId: 'cma-part-2', name: 'Corporate Finance'),
  ],
  subUnits: const [
    SubUnit(
      id: 'subunit-budgeting',
      unitId: 'unit-financial-planning',
      name: 'Budgeting',
    ),
    SubUnit(id: 'subunit-2', unitId: 'unit-2', name: 'Capital'),
  ],
  topics: const [
    Topic(
      id: 'topic-1',
      subUnitId: 'subunit-budgeting',
      name: 'Flexible Budget',
      publishedQuestionCount: 10,
    ),
    Topic(
      id: 'topic-2',
      subUnitId: 'subunit-budgeting',
      name: 'Master Budget',
      publishedQuestionCount: 10,
    ),
    Topic(
      id: 'topic-3',
      subUnitId: 'subunit-2',
      name: 'Cost of Capital',
      publishedQuestionCount: 10,
    ),
  ],
);

/// Serves [examCurriculumTree] — the curriculum every exam test browses.
class FakeCurriculumRepository implements CurriculumRepository {
  @override
  Future<Result<List<Program>>> getPrograms() async =>
      const Result.success([Program(id: 'program-cma', name: 'CMA')]);

  @override
  Future<Result<CurriculumTree>> getProgramTree(String programId) async =>
      Result.success(examCurriculumTree());
}

/// Drives the real Setup screen (CMA is preselected from the student's
/// access) to the Active exam with [examRepository].
Future<void> startExamViaSetup(
  WidgetTester tester,
  ExamRepository examRepository, {
  String part = 'Part 1',
  String? questionCount,
  Locale? locale,
  ThemeMode? themeMode,
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    wrapExamScreen(
      examRepository: examRepository,
      curriculumRepository: FakeCurriculumRepository(),
      locale: locale,
      themeMode: themeMode,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<Part>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(part).last);
  await tester.pumpAndSettle();
  if (questionCount != null) {
    await tester.tap(find.widgetWithText(ChoiceChip, questionCount));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

/// The CMA Part 2 attempt the connected-loop tests use: 25 questions; once
/// submitted, 8 answered, 2 correct, after 41 s — the 8% attempt in
/// test/features/performance/local_attempt_test_data.dart.
ExamAttempt cmaPart2Attempt({String status = 'IN_PROGRESS', int answered = 0}) {
  final ended = status != 'IN_PROGRESS';
  return fakeAttempt(
    id: 'mock-attempt-0',
    status: status,
    durationMinutes: 30,
    submittedAfter: const Duration(seconds: 41),
    questions: [
      for (var i = 0; i < 25; i++)
        () {
          final question = FakeExamQuestion(
            id: 'cq$i',
            text: i == 0 ? 'Exam question' : 'Exam question ${i + 1}',
            choices: {
              'cq$i-a': i == 0 ? 'Exam answer' : 'Right',
              'cq$i-b': 'Wrong',
            },
            correctChoiceId: 'cq$i-a',
            topicId: 'topic-cost-behavior',
            topicName: 'Cost Behavior',
          );
          final isAnswered = ended ? i < 8 : i < answered;
          if (!isAnswered) return question;
          return question.answer(i < 2 ? 'cq$i-a' : 'cq$i-b');
        }(),
    ],
  );
}
