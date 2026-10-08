import '../../../../core/error/app_failure.dart';
import '../../domain/entities/exam_config.dart';
import '../../domain/entities/exam_question.dart';
import '../../domain/entities/exam_result.dart';
import '../../domain/entities/exam_review_item.dart';

/// Exam Simulation state machine. Deliberately scoped to this feature only
/// — no unrelated app state lives here, and nothing outside this feature
/// reads it directly (screens go through [examNotifierProvider]).
///
/// Unlike study_session's `StudySessionState`, there is no per-question
/// "phase" (ready/answering/feedback) — Exam Simulation never reveals
/// correctness during the exam, so a selected choice never changes to a
/// locked or resolved visual state; only "selected or not" exists, right up
/// to submission. That's a real behavioral difference from Study Session,
/// not a missing feature.
sealed class ExamState {
  const ExamState();
}

class ExamInitial extends ExamState {
  const ExamInitial();
}

/// Starting an exam (awaiting [ExamRepository.startExam]).
class ExamLoading extends ExamState {
  const ExamLoading();
}

class ExamActive extends ExamState {
  const ExamActive({
    required this.config,
    required this.attemptId,
    required this.questions,
    required this.currentIndex,
    required this.selectedAnswers,
    required this.flaggedQuestionIds,
    required this.totalDurationSeconds,
    required this.remainingSeconds,
  });

  final ExamConfig config;
  final String attemptId;
  final List<ExamQuestion> questions;
  final int currentIndex;

  /// questionId → selected choice id. Never sent to the server until final
  /// submission — Exam Simulation has no per-question network call (no
  /// feedback exists to return), unlike Study Session's immediate mode.
  final Map<String, String> selectedAnswers;

  /// questionId set — a review/navigation aid only. Never sent to the
  /// server as anything that could affect scoring; see [ExamRepository.submitExam].
  final Set<String> flaggedQuestionIds;

  /// The server-authoritative duration this attempt started with (from
  /// [ExamAttempt.durationSeconds], never from [ExamConfig.duration] —
  /// that field is only the client's *request*). Used to compute time
  /// taken at submission.
  final int totalDurationSeconds;

  /// Counts down to 0. Ticked by the notifier's `Timer.periodic`, never by
  /// widget rebuilds — see ExamNotifier's "Timer architecture" doc comment.
  final int remainingSeconds;

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
    int? currentIndex,
    Map<String, String>? selectedAnswers,
    Set<String>? flaggedQuestionIds,
    int? remainingSeconds,
  }) {
    return ExamActive(
      config: config,
      attemptId: attemptId,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      totalDurationSeconds: totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// The countdown reached zero. A distinct, visible moment between
/// [ExamActive] and [ExamSubmitting] — the UI shows a "time expired,
/// submitting…" message here rather than jumping straight to a generic
/// submitting spinner, so the student understands *why* the exam ended.
/// Carries the final [active] snapshot (remainingSeconds == 0) so the
/// submission it immediately triggers has the real answers/flags to send.
class ExamTimedOut extends ExamState {
  const ExamTimedOut(this.active);

  final ExamActive active;
}

/// Final submission in flight (either student-initiated or auto-triggered
/// by [ExamTimedOut]). Carries the [active] snapshot it was submitted from
/// so a failure can restore it exactly — submitting must never discard the
/// student's answers.
class ExamSubmitting extends ExamState {
  const ExamSubmitting(this.active, {this.isTimeoutSubmission = false});

  final ExamActive active;

  /// True when this submission was auto-triggered by the timer reaching
  /// zero rather than the student pressing Submit — lets the UI keep
  /// showing "time expired" framing through the submitting state too.
  final bool isTimeoutSubmission;
}

class ExamCompleted extends ExamState {
  const ExamCompleted({
    required this.config,
    required this.result,
    required this.review,
  });

  final ExamConfig config;

  /// Authoritative — sourced from the backend, never recomputed locally.
  final ExamResult result;
  final List<ExamReviewItem> review;
}

/// An exam failed to start or submit. [retryFrom], when non-null, is the
/// active snapshot to resume from if the student retries rather than
/// abandoning the attempt (e.g. a submit that failed on a network error).
/// `null` only when there is nothing to resume — e.g. starting an exam
/// failed before any questions were ever loaded.
class ExamError extends ExamState {
  const ExamError({
    required this.failure,
    this.retryFrom,
    this.wasTimeout = false,
  });

  final AppFailure failure;
  final ExamActive? retryFrom;

  /// True when this error happened while submitting a timeout-triggered
  /// submission — the UI should keep timeout framing on the retry prompt
  /// rather than a generic "submission failed" message.
  final bool wasTimeout;
}
