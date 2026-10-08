import 'exam_answer_choice.dart';
import 'exam_question.dart';
import 'exam_question_type.dart';
import 'exam_result.dart';
import 'exam_review_item.dart';

enum ExamAttemptStatus { inProgress, submitted, expired }

class ExamProgress {
  const ExamProgress({
    required this.total,
    required this.answered,
    required this.flagged,
  });

  final int total;
  final int answered;
  final int flagged;
}

class ExamScore {
  const ExamScore({
    required this.correct,
    required this.incorrect,
    required this.unanswered,
  });

  final int correct;
  final int incorrect;
  final int unanswered;
}

/// One choice as the server sent it. [isCorrect] is `null` until the
/// attempt is no longer in progress.
class ExamAttemptChoice {
  const ExamAttemptChoice({
    required this.id,
    required this.text,
    this.isCorrect,
  });

  final String id;
  final String text;
  final bool? isCorrect;
}

/// One question of an attempt with the student's progress on it.
class ExamAttemptQuestion {
  const ExamAttemptQuestion({
    required this.questionId,
    required this.order,
    required this.text,
    required this.topicId,
    required this.topicName,
    required this.choices,
    this.explanation,
    this.isFlagged = false,
    this.answeredAt,
    this.timeSpentSeconds = 0,
    this.selectedChoiceId,
    this.isCorrect,
  });

  /// The bank question id — the one used in URLs.
  final String questionId;
  final int order;
  final String text;

  /// In the payload from the start, but never shown while the attempt is
  /// in progress (contract §A4).
  final String topicId;
  final String topicName;
  final List<ExamAttemptChoice> choices;
  final String? explanation;
  final bool isFlagged;
  final DateTime? answeredAt;
  final int timeSpentSeconds;
  final String? selectedChoiceId;
  final bool? isCorrect;

  bool get isAnswered => answeredAt != null;

  String? get correctChoiceId {
    for (final choice in choices) {
      if (choice.isCorrect == true) return choice.id;
    }
    return null;
  }

  /// The question as shown during the exam — no topic, no correctness.
  ExamQuestion toQuestion() => ExamQuestion(
    id: questionId,
    text: text,
    type: ExamQuestionType.multipleChoiceSingle,
    choices: [
      for (final (index, choice) in choices.indexed)
        ExamAnswerChoice(id: choice.id, text: choice.text, order: index),
    ],
  );
}

/// An exam attempt as every `/exams/attempts` endpoint returns it (contract
/// §A4). The server owns the clock: an attempt read or written after
/// [expiresAt] comes back `EXPIRED`.
class ExamAttempt {
  const ExamAttempt({
    required this.id,
    required this.status,
    required this.durationMinutes,
    required this.topicIds,
    required this.requestedCount,
    required this.startedAt,
    required this.expiresAt,
    required this.remainingSeconds,
    required this.progress,
    required this.questions,
    this.submittedAt,
    this.score,
  });

  final String id;
  final ExamAttemptStatus status;
  final int durationMinutes;
  final List<String> topicIds;
  final int requestedCount;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? submittedAt;
  final int remainingSeconds;
  final ExamProgress progress;

  /// `null` while in progress.
  final ExamScore? score;

  /// In the server's (shuffled) order.
  final List<ExamAttemptQuestion> questions;

  bool get isInProgress => status == ExamAttemptStatus.inProgress;

  int get durationSeconds => durationMinutes * 60;

  /// The result table from contract §A4.
  ExamResult toResult() {
    final score =
        this.score ??
        ExamScore(correct: 0, incorrect: 0, unanswered: progress.total);
    final total = progress.total;
    final end = submittedAt ?? expiresAt;
    return ExamResult(
      attemptId: id,
      totalQuestions: total,
      answered: total - score.unanswered,
      unanswered: score.unanswered,
      correct: score.correct,
      incorrect: score.incorrect,
      scorePercent: total == 0 ? 0 : score.correct / total * 100,
      durationTaken: end.difference(startedAt).isNegative
          ? Duration.zero
          : end.difference(startedAt),
      completionStatus: status == ExamAttemptStatus.expired
          ? 'timed_out'
          : 'completed',
    );
  }

  /// Every question, revealed once the attempt isn't in progress.
  List<ExamReviewItem> toReview() => [
    for (final question in questions)
      ExamReviewItem(
        questionId: question.questionId,
        questionText: question.text,
        choices: question.toQuestion().choices,
        correctChoiceId: question.correctChoiceId,
        selectedChoiceId: question.selectedChoiceId,
        isCorrect: question.isCorrect ?? false,
        wasFlagged: question.isFlagged,
        explanation: question.explanation,
        topicId: question.topicId,
        topicName: question.topicName,
      ),
  ];
}

/// A row of `GET /exams/attempts` — no questions.
class ExamAttemptSummary {
  const ExamAttemptSummary({
    required this.id,
    required this.status,
    required this.durationMinutes,
    required this.topicIds,
    required this.requestedCount,
    required this.startedAt,
    required this.expiresAt,
    this.submittedAt,
  });

  final String id;
  final ExamAttemptStatus status;
  final int durationMinutes;
  final List<String> topicIds;
  final int requestedCount;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? submittedAt;

  /// Still running, by the server's status and the clock — an attempt past
  /// [expiresAt] is only marked `EXPIRED` the next time it's read.
  bool isOpenAt(DateTime now) =>
      status == ExamAttemptStatus.inProgress && now.isBefore(expiresAt);
}
