import '../../../../core/error/app_failure.dart';
import '../../domain/entities/exam_attempt.dart';
import '../../domain/entities/exam_config.dart';
import '../../domain/entities/exam_question.dart';
import '../../domain/entities/exam_result.dart';
import '../../domain/entities/exam_review_item.dart';

/// Exam Simulation state machine — entirely separate from Study Session's.
sealed class ExamState {
  const ExamState();
}

class ExamInitial extends ExamState {
  const ExamInitial();
}

/// Starting or reopening an attempt.
class ExamLoading extends ExamState {
  const ExamLoading();
}

/// An attempt in progress. [attempt] is the server's copy — answers, flags
/// and progress come from it; the local additions are the question on
/// screen, a choice whose save is in flight, and the countdown.
class ExamActive extends ExamState {
  ExamActive({
    required this.config,
    required this.attempt,
    required this.currentIndex,
    required this.remainingSeconds,
    this.draftChoices = const {},
  });

  final ExamConfig config;
  final ExamAttempt attempt;
  final int currentIndex;

  /// Counts down from the server's `remainingSeconds`.
  final int remainingSeconds;

  /// questionId → a choice whose answer call is still in flight.
  final Map<String, String> draftChoices;

  String get attemptId => attempt.id;
  int get totalDurationSeconds => attempt.durationSeconds;

  late final List<ExamQuestion> questions = [
    for (final question in attempt.questions) question.toQuestion(),
  ];

  /// Every recorded answer, with in-flight picks on top.
  late final Map<String, String> selectedAnswers = {
    for (final question in attempt.questions)
      if (question.selectedChoiceId != null)
        question.questionId: question.selectedChoiceId!,
    ...draftChoices,
  };

  late final Set<String> flaggedQuestionIds = {
    for (final question in attempt.questions)
      if (question.isFlagged) question.questionId,
  };

  ExamQuestion get currentQuestion => questions[currentIndex];
  int get totalQuestions => questions.length;
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get isFirstQuestion => currentIndex == 0;
  int get answeredCount => selectedAnswers.length;
  int get unansweredCount => totalQuestions - answeredCount;
  int get flaggedCount => flaggedQuestionIds.length;
  String? get selectedChoiceForCurrent => selectedAnswers[currentQuestion.id];
  bool get isCurrentFlagged => flaggedQuestionIds.contains(currentQuestion.id);

  ExamActive copyWith({
    ExamAttempt? attempt,
    int? currentIndex,
    int? remainingSeconds,
    Map<String, String>? draftChoices,
  }) {
    return ExamActive(
      config: config,
      attempt: attempt ?? this.attempt,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      draftChoices: draftChoices ?? this.draftChoices,
    );
  }
}

/// The countdown reached zero; the attempt is being submitted.
class ExamTimedOut extends ExamState {
  const ExamTimedOut(this.active);

  final ExamActive active;
}

class ExamSubmitting extends ExamState {
  const ExamSubmitting(this.active, {this.isTimeoutSubmission = false});

  final ExamActive active;
  final bool isTimeoutSubmission;
}

class ExamCompleted extends ExamState {
  const ExamCompleted({
    required this.config,
    required this.attempt,
    required this.result,
    required this.review,
  });

  final ExamConfig config;
  final ExamAttempt attempt;

  /// Derived from the server's finished attempt.
  final ExamResult result;
  final List<ExamReviewItem> review;
}

/// Starting, reopening or submitting failed. [retryFrom] is the active
/// snapshot to go back to after a failed submission.
class ExamError extends ExamState {
  const ExamError({
    required this.failure,
    this.retryFrom,
    this.wasTimeout = false,
  });

  final AppFailure failure;
  final ExamActive? retryFrom;
  final bool wasTimeout;
}
