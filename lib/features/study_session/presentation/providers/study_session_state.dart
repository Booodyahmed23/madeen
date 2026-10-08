import '../../../../core/error/app_failure.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/question_feedback.dart';
import '../../domain/entities/question_review_item.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/session_result.dart';

/// Where the student is on the *current* question, while [StudySessionActive].
/// Covers this phase's minimum-state requirement (Ready/Answering/Feedback)
/// as a field on the active state rather than three near-duplicate state
/// classes — Ready→Answering→Feedback share every field (config, questions,
/// index, answers, timer...); only what's drawn on screen changes.
enum QuestionPhase {
  /// Question shown, nothing selected yet.
  ready,

  /// Student has picked a choice but not (yet, in immediate mode) submitted
  /// it. In "feedback at end" mode this is also the terminal phase for a
  /// question — Next simply moves on, nothing is ever revealed here.
  answering,

  /// Immediate-feedback mode only, after [QuestionFeedback] comes back:
  /// correct/incorrect + correct choice + explanation are now safe to show
  /// for *this* question only.
  feedback,
}

/// Study Session state machine. Deliberately scoped to this feature only —
/// no unrelated app state lives here, and nothing outside this feature reads
/// it directly (screens go through [studySessionNotifierProvider]).
sealed class StudySessionState {
  const StudySessionState();
}

class StudySessionInitial extends StudySessionState {
  const StudySessionInitial();
}

/// Starting a session (awaiting [StudySessionRepository.startSession]).
class StudySessionLoading extends StudySessionState {
  const StudySessionLoading();
}

class StudySessionActive extends StudySessionState {
  const StudySessionActive({
    required this.config,
    required this.sessionId,
    required this.questions,
    required this.currentIndex,
    required this.selectedAnswers,
    required this.answeredQuestionIds,
    required this.feedbackByQuestion,
    required this.phase,
    required this.elapsed,
    required this.isPaused,
    this.isSubmittingAnswer = false,
  });

  final SessionConfig config;
  final String sessionId;
  final List<Question> questions;
  final int currentIndex;

  /// questionId → selected choice id. Holds every choice the student has
  /// made so far, in *both* feedback modes — in "at end" mode this is the
  /// only record of answers, sent all at once by [submitSession]; in
  /// immediate mode it's kept in step with what's already been confirmed
  /// server-side via [answeredQuestionIds].
  final Map<String, String> selectedAnswers;

  /// Immediate-feedback mode only: questions already confirmed via
  /// submitAnswer — locks the choice tiles so a confirmed answer can't be
  /// silently changed after the correct answer has been shown.
  final Set<String> answeredQuestionIds;

  /// Immediate-feedback mode only: questionId → the feedback returned for
  /// it. Never populated in "feedback at end" mode.
  final Map<String, QuestionFeedback> feedbackByQuestion;

  final QuestionPhase phase;
  final Duration elapsed;
  final bool isPaused;

  /// True only while an immediate-mode submitAnswer call is in flight.
  final bool isSubmittingAnswer;

  Question get currentQuestion => questions[currentIndex];
  int get totalQuestions => questions.length;
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get isFirstQuestion => currentIndex == 0;
  int get answeredCount => selectedAnswers.length;
  int get unansweredCount => totalQuestions - answeredCount;
  String? get selectedChoiceForCurrent => selectedAnswers[currentQuestion.id];
  QuestionFeedback? get feedbackForCurrent =>
      feedbackByQuestion[currentQuestion.id];

  StudySessionActive copyWith({
    int? currentIndex,
    Map<String, String>? selectedAnswers,
    Set<String>? answeredQuestionIds,
    Map<String, QuestionFeedback>? feedbackByQuestion,
    QuestionPhase? phase,
    Duration? elapsed,
    bool? isPaused,
    bool? isSubmittingAnswer,
  }) {
    return StudySessionActive(
      config: config,
      sessionId: sessionId,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      answeredQuestionIds: answeredQuestionIds ?? this.answeredQuestionIds,
      feedbackByQuestion: feedbackByQuestion ?? this.feedbackByQuestion,
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      isPaused: isPaused ?? this.isPaused,
      isSubmittingAnswer: isSubmittingAnswer ?? this.isSubmittingAnswer,
    );
  }
}

/// Final submission in flight. Carries the [active] snapshot it was
/// submitted from so a failure can restore it exactly — submitting must
/// never discard the student's answers.
class StudySessionSubmitting extends StudySessionState {
  const StudySessionSubmitting(this.active);

  final StudySessionActive active;
}

class StudySessionCompleted extends StudySessionState {
  const StudySessionCompleted({
    required this.config,
    required this.result,
    required this.review,
  });

  final SessionConfig config;

  /// Authoritative — sourced from the backend, never recomputed locally.
  final SessionResult result;
  final List<QuestionReviewItem> review;
}

/// A session failed to start or submit. [retryFrom], when non-null, is the
/// active snapshot to resume from if the student retries rather than
/// abandoning the session (e.g. a submit that failed on a network error).
/// `null` only when there is nothing to resume — e.g. starting a session
/// failed before any questions were ever loaded.
class StudySessionError extends StudySessionState {
  const StudySessionError({required this.failure, this.retryFrom});

  final AppFailure failure;
  final StudySessionActive? retryFrom;
}
