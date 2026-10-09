import 'answer_choice.dart';
import 'question.dart';
import 'question_feedback.dart';
import 'question_review_item.dart';
import 'question_type.dart';
import 'session_config.dart';
import 'session_result.dart';

enum StudySessionStatus { inProgress, paused, completed }

class SessionProgress {
  const SessionProgress({
    required this.total,
    required this.answered,
    required this.flagged,
    required this.correct,
  });

  final int total;
  final int answered;
  final int flagged;
  final int correct;
}

class SessionTopic {
  const SessionTopic({required this.id, required this.name});

  final String id;
  final String name;
}

/// One choice as the server sent it. [isCorrect] is `null` until the
/// question is revealed.
class SessionChoice {
  const SessionChoice({required this.id, required this.text, this.isCorrect});

  final String id;
  final String text;
  final bool? isCorrect;
}

/// One question of a session, with the student's progress on it.
class SessionQuestion {
  const SessionQuestion({
    required this.questionId,
    required this.order,
    required this.text,
    required this.topic,
    required this.choices,
    this.code,
    this.losCode,
    this.difficulty,
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
  final SessionTopic topic;
  final List<SessionChoice> choices;
  final int? code;
  final String? losCode;

  /// `EASY` | `MEDIUM` | `HARD`.
  final String? difficulty;

  /// Only present once revealed.
  final String? explanation;
  final bool isFlagged;
  final DateTime? answeredAt;
  final int timeSpentSeconds;
  final String? selectedChoiceId;

  /// `null` until revealed, and for skipped questions.
  final bool? isCorrect;

  bool get isAnswered => answeredAt != null;

  /// The server includes `choices[].isCorrect` only for revealed questions.
  bool get isRevealed => choices.any((c) => c.isCorrect != null);

  String? get correctChoiceId {
    for (final choice in choices) {
      if (choice.isCorrect == true) return choice.id;
    }
    return null;
  }

  /// The question as shown while answering — no correctness information.
  Question toQuestion() => Question(
    id: questionId,
    text: text,
    type: QuestionType.multipleChoiceSingle,
    choices: [
      for (final (index, choice) in choices.indexed)
        AnswerChoice(id: choice.id, text: choice.text, order: index),
    ],
    difficulty: difficulty,
    code: code,
    losCode: losCode,
  );
}

/// A study session as the API returns it from every study endpoint
/// (contract §A3). The server owns answers, flags, progress, timing and
/// what is revealed; the app derives everything it shows from this.
class StudySession {
  const StudySession({
    required this.id,
    required this.status,
    required this.feedbackMode,
    required this.topicIds,
    required this.requestedCount,
    required this.createdAt,
    required this.progress,
    required this.questions,
    this.difficulty,
    this.completedAt,
  });

  final String id;
  final StudySessionStatus status;
  final FeedbackMode feedbackMode;
  final List<String> topicIds;
  final String? difficulty;
  final int requestedCount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final SessionProgress progress;

  /// In the server's (shuffled) order.
  final List<SessionQuestion> questions;

  bool get isCompleted => status == StudySessionStatus.completed;

  /// Whether the student may still change [question]'s answer: never once
  /// the session isn't in progress, and not after immediate feedback was
  /// shown (the API would allow it; the app locks it — contract §A3).
  bool isLocked(SessionQuestion question) =>
      status != StudySessionStatus.inProgress ||
      (feedbackMode == FeedbackMode.immediate && question.isAnswered);

  SessionQuestion? questionById(String questionId) {
    for (final question in questions) {
      if (question.questionId == questionId) return question;
    }
    return null;
  }

  /// Immediate feedback for an answered, revealed question.
  QuestionFeedback? feedbackFor(String questionId) {
    final question = questionById(questionId);
    final correctChoiceId = question?.correctChoiceId;
    if (question == null ||
        !question.isAnswered ||
        correctChoiceId == null ||
        question.isCorrect == null) {
      return null;
    }
    return QuestionFeedback(
      questionId: questionId,
      isCorrect: question.isCorrect!,
      correctChoiceId: correctChoiceId,
      explanation: question.explanation,
    );
  }

  /// The result table from contract §A3.
  SessionResult toResult() {
    final totalSeconds = questions.fold<int>(
      0,
      (sum, q) => sum + q.timeSpentSeconds,
    );
    final total = progress.total;
    final answered = progress.answered;
    return SessionResult(
      sessionId: id,
      totalQuestions: total,
      answered: answered,
      unanswered: total - answered,
      correct: progress.correct,
      incorrect: answered - progress.correct,
      scorePercent: total == 0 ? 0 : progress.correct / total * 100,
      totalTime: Duration(seconds: totalSeconds),
      averageTimePerQuestion: answered == 0
          ? Duration.zero
          : Duration(seconds: (totalSeconds / answered).round()),
    );
  }

  /// The post-session review — built from the completed session.
  List<QuestionReviewItem> toReview() => [
    for (final question in questions)
      QuestionReviewItem(
        questionId: question.questionId,
        questionText: question.text,
        choices: question.toQuestion().choices,
        correctChoiceId: question.correctChoiceId,
        selectedChoiceId: question.selectedChoiceId,
        isCorrect: question.isCorrect,
        explanation: question.explanation,
      ),
  ];
}

/// A row of `GET /study/sessions` — no questions.
class StudySessionSummary {
  const StudySessionSummary({
    required this.id,
    required this.status,
    required this.feedbackMode,
    required this.topicIds,
    required this.requestedCount,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final StudySessionStatus status;
  final FeedbackMode feedbackMode;
  final List<String> topicIds;
  final int requestedCount;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => status == StudySessionStatus.completed;
}
