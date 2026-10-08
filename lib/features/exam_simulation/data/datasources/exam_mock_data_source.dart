import 'dart:math';

import '../../domain/entities/exam_config.dart';
import '../../domain/entities/exam_question_type.dart';
import '../models/exam_answer_choice_model.dart';
import '../models/exam_attempt_model.dart';
import '../models/exam_question_model.dart';
import '../models/exam_result_model.dart';
import '../models/exam_review_item_model.dart';
import 'exam_data_source.dart';

typedef _MockTopic = ({String id, String name});

class _MockAttempt {
  _MockAttempt(
    this.questions,
    this.correctChoiceByQuestion,
    this.topicByQuestion,
    this.durationSeconds,
  );

  final List<ExamQuestionModel> questions;
  final Map<String, String> correctChoiceByQuestion;
  final Map<String, _MockTopic> topicByQuestion;
  final int durationSeconds;
  Map<String, String?> lastAnswers = const {};
  Set<String> lastFlags = const {};
}

/// Local sample exam — used only because the real Exam Simulation API does
/// not exist yet (see EXAM_SIMULATION_API_REQUIREMENTS.md). Generates a
/// plausible multiple-choice set for any [ExamConfig], deliberately with no
/// topic/curriculum text anywhere in the generated content — this is a
/// UI-development aid, **not** production exam content, and not the real
/// CMA/FMAA exam question count or duration (see kExamQuestionCountOptions
/// / examDurationFor).
///
/// Each question is quietly assigned a topic from the configured scope
/// (round-robin over [_topicsByScope]) — revealed only by [getReview],
/// after submission, never on the question itself.
class ExamMockDataSource implements ExamDataSource {
  ExamMockDataSource({Random? random}) : _random = random ?? Random();

  static const _artificialDelay = Duration(milliseconds: 400);
  static const _choiceLetters = ['A', 'B', 'C', 'D'];

  final Random _random;

  /// Topics under each curriculum node, mirroring the ids and names of the
  /// Curriculum feature's own sample data, so a mock exam's per-topic
  /// results line up with the same topics in Performance.
  static const Map<String, List<_MockTopic>> _topicsByScope = {
    'subunit-budgeting': [
      (id: 'topic-flexible-budget', name: 'Flexible Budget'),
      (id: 'topic-master-budget', name: 'Master Budget'),
      (id: 'topic-variance-analysis', name: 'Variance Analysis'),
    ],
    'subunit-cost-concepts': [
      (id: 'topic-cost-behavior', name: 'Cost Behavior'),
    ],
    'unit-financial-planning': [
      (id: 'topic-flexible-budget', name: 'Flexible Budget'),
      (id: 'topic-master-budget', name: 'Master Budget'),
      (id: 'topic-variance-analysis', name: 'Variance Analysis'),
    ],
    'unit-cost-management': [
      (id: 'topic-cost-behavior', name: 'Cost Behavior'),
    ],
    'cma-part-1': [
      (id: 'topic-flexible-budget', name: 'Flexible Budget'),
      (id: 'topic-master-budget', name: 'Master Budget'),
      (id: 'topic-variance-analysis', name: 'Variance Analysis'),
      (id: 'topic-cost-behavior', name: 'Cost Behavior'),
    ],
  };

  /// The narrowest configured scope's topics. A scope with no sample
  /// topics groups its questions under that scope node itself, so the
  /// per-topic breakdown is never empty for a mock exam.
  static List<_MockTopic> _topicsFor(ExamConfig config) {
    final (id, name) = config.subUnitId != null
        ? (config.subUnitId!, config.subUnitName ?? config.subUnitId!)
        : config.unitId != null
        ? (config.unitId!, config.unitName ?? config.unitId!)
        : (config.partId, '${config.programName} ${config.partName}');
    return _topicsByScope[id] ?? [(id: id, name: name)];
  }

  final _attempts = <String, _MockAttempt>{};
  var _attemptCounter = 0;

  @override
  Future<ExamAttemptModel> startExam(ExamConfig config) async {
    await Future<void>.delayed(_artificialDelay);

    final questions = List.generate(config.questionCount, (index) {
      final questionId = 'mock-exam-q-${config.partId}-$index';
      final correctIndex = index % _choiceLetters.length;
      final choices = List.generate(
        _choiceLetters.length,
        (choiceIndex) => ExamAnswerChoiceModel(
          id: '$questionId-choice-$choiceIndex',
          text:
              '${_choiceLetters[choiceIndex]}) Sample exam answer ${choiceIndex + 1} for question ${index + 1}',
          order: choiceIndex,
        ),
      );
      return (
        model: ExamQuestionModel(
          id: questionId,
          text: 'Sample exam question ${index + 1}.',
          type: ExamQuestionType.multipleChoiceSingle,
          choices: choices,
        ),
        correctChoiceId: choices[correctIndex].id,
      );
    });

    if (config.questionOrder == ExamQuestionOrder.random) {
      questions.shuffle(_random);
    }
    final topics = _topicsFor(config);

    final attemptId = 'mock-attempt-${_attemptCounter++}';
    // The server is authoritative for duration — the mock deliberately
    // echoes the requested config duration back rather than inventing a
    // different one, since there is no real business rule to diverge with
    // yet. A real backend might clamp or override this.
    final durationSeconds = config.duration.inSeconds;
    _attempts[attemptId] = _MockAttempt(
      [for (final q in questions) q.model],
      {for (final q in questions) q.model.id: q.correctChoiceId},
      {
        for (var i = 0; i < questions.length; i++)
          questions[i].model.id: topics[i % topics.length],
      },
      durationSeconds,
    );

    return ExamAttemptModel(
      attemptId: attemptId,
      questions: [for (final q in questions) q.model],
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<ExamAttemptModel> getAttempt(String attemptId) async {
    await Future<void>.delayed(_artificialDelay);
    final attempt = _attempts[attemptId];
    if (attempt == null) {
      throw StateError('Unknown mock exam attempt: $attemptId');
    }
    return ExamAttemptModel(
      attemptId: attemptId,
      questions: attempt.questions,
      durationSeconds: attempt.durationSeconds,
    );
  }

  @override
  Future<ExamResultModel> submitExam({
    required String attemptId,
    required Map<String, String?> answers,
    required Set<String> flaggedQuestionIds,
    required Duration timeTaken,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final attempt = _attempts[attemptId];
    if (attempt == null) {
      throw StateError('Unknown mock exam attempt: $attemptId');
    }
    attempt.lastAnswers = answers;
    attempt.lastFlags = flaggedQuestionIds;

    final total = attempt.questions.length;
    var correct = 0;
    var answeredCount = 0;
    for (final question in attempt.questions) {
      final selected = answers[question.id];
      if (selected != null) {
        answeredCount++;
        if (selected == attempt.correctChoiceByQuestion[question.id]) correct++;
      }
    }
    final unanswered = total - answeredCount;
    final incorrect = answeredCount - correct;

    return ExamResultModel(
      attemptId: attemptId,
      totalQuestions: total,
      answered: answeredCount,
      unanswered: unanswered,
      correct: correct,
      incorrect: incorrect,
      scorePercent: total == 0 ? 0 : (correct / total) * 100,
      durationTakenSeconds: timeTaken.inSeconds,
      // Using the whole countdown means the timer ran out (the client
      // auto-submits at zero) — the mock's stand-in for the server's own
      // deadline check.
      completionStatus: timeTaken.inSeconds >= attempt.durationSeconds
          ? 'timed_out'
          : 'completed',
    );
  }

  @override
  Future<List<ExamReviewItemModel>> getReview(String attemptId) async {
    await Future<void>.delayed(_artificialDelay);
    final attempt = _attempts[attemptId];
    if (attempt == null) return const [];

    return [
      for (final question in attempt.questions)
        ExamReviewItemModel(
          questionId: question.id,
          questionText: question.text,
          choices: question.choices,
          correctChoiceId: attempt.correctChoiceByQuestion[question.id]!,
          selectedChoiceId: attempt.lastAnswers[question.id],
          isCorrect:
              attempt.lastAnswers[question.id] != null &&
              attempt.lastAnswers[question.id] ==
                  attempt.correctChoiceByQuestion[question.id],
          wasFlagged: attempt.lastFlags.contains(question.id),
          explanation:
              'This is sample explanation text for a mock exam question — '
              'replace once the real Exam Simulation API is connected.',
          topicId: attempt.topicByQuestion[question.id]?.id,
          topicName: attempt.topicByQuestion[question.id]?.name,
        ),
    ];
  }
}
