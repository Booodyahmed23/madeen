import '../../../../core/error/app_failure.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/question_feedback.dart';
import '../../domain/entities/question_review_item.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/session_result.dart';
import '../../domain/entities/study_session.dart';

/// Where the student is on the *current* question, while [StudySessionActive].
enum QuestionPhase {
  /// Question shown, nothing selected yet.
  ready,

  /// A choice is selected. In immediate mode it isn't checked yet; in
  /// "feedback at end" mode this is the terminal phase for a question.
  answering,

  /// Immediate mode only: the server revealed this answered question.
  feedback,
}

/// Study Session state machine. Deliberately scoped to this feature only —
/// screens go through [studySessionNotifierProvider].
sealed class StudySessionState {
  const StudySessionState();
}

class StudySessionInitial extends StudySessionState {
  const StudySessionInitial();
}

/// Starting or reopening a session.
class StudySessionLoading extends StudySessionState {
  const StudySessionLoading();
}

/// A session in progress (or paused). [session] is the server's copy —
/// answers, flags, progress and reveals all come from it; the only local
/// additions are which question is on screen, an immediate-mode choice not
/// yet checked, and the running clock.
class StudySessionActive extends StudySessionState {
  StudySessionActive({
    required this.config,
    required this.session,
    required this.currentIndex,
    this.draftChoices = const {},
    required this.elapsed,
    required this.isPaused,
    this.isSubmittingAnswer = false,
  });

  final SessionConfig config;
  final StudySession session;
  final int currentIndex;

  /// questionId → a choice picked but not yet sent: immediate mode before
  /// "Check answer", or while the answer call is in flight.
  final Map<String, String> draftChoices;
  final Duration elapsed;
  final bool isPaused;

  /// True while an answer call is in flight.
  final bool isSubmittingAnswer;

  String get sessionId => session.id;

  late final List<Question> questions = [
    for (final question in session.questions) question.toQuestion(),
  ];

  SessionQuestion get currentSessionQuestion => session.questions[currentIndex];

  Question get currentQuestion => questions[currentIndex];
  int get totalQuestions => questions.length;
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get isFirstQuestion => currentIndex == 0;

  /// Answers the server has recorded.
  int get answeredCount => session.progress.answered;
  int get unansweredCount => totalQuestions - answeredCount;

  bool isAnswered(String questionId) =>
      session.questionById(questionId)?.isAnswered ?? false;

  String? selectedChoiceFor(String questionId) =>
      draftChoices[questionId] ??
      session.questionById(questionId)?.selectedChoiceId;

  String? get selectedChoiceForCurrent => selectedChoiceFor(currentQuestion.id);

  /// Only in immediate mode — deferred answers are revealed at the end.
  QuestionFeedback? get feedbackForCurrent =>
      config.feedbackMode == FeedbackMode.immediate
      ? session.feedbackFor(currentQuestion.id)
      : null;

  bool get isCurrentLocked => session.isLocked(currentSessionQuestion);

  bool get isCurrentFlagged => currentSessionQuestion.isFlagged;

  QuestionPhase get phase {
    if (feedbackForCurrent != null) return QuestionPhase.feedback;
    if (selectedChoiceForCurrent != null) return QuestionPhase.answering;
    return QuestionPhase.ready;
  }

  StudySessionActive copyWith({
    StudySession? session,
    int? currentIndex,
    Map<String, String>? draftChoices,
    Duration? elapsed,
    bool? isPaused,
    bool? isSubmittingAnswer,
  }) {
    return StudySessionActive(
      config: config,
      session: session ?? this.session,
      currentIndex: currentIndex ?? this.currentIndex,
      draftChoices: draftChoices ?? this.draftChoices,
      elapsed: elapsed ?? this.elapsed,
      isPaused: isPaused ?? this.isPaused,
      isSubmittingAnswer: isSubmittingAnswer ?? this.isSubmittingAnswer,
    );
  }
}

/// Completion in flight. Carries the [active] snapshot so a failure can
/// restore it exactly.
class StudySessionSubmitting extends StudySessionState {
  const StudySessionSubmitting(this.active);

  final StudySessionActive active;
}

class StudySessionCompleted extends StudySessionState {
  const StudySessionCompleted({
    required this.config,
    required this.session,
    required this.result,
    required this.review,
  });

  final SessionConfig config;
  final StudySession session;

  /// Derived from the server's completed session.
  final SessionResult result;
  final List<QuestionReviewItem> review;
}

/// A session failed to start, reopen or complete. [retryFrom], when
/// non-null, is the active snapshot to go back to (a failed completion).
class StudySessionError extends StudySessionState {
  const StudySessionError({required this.failure, this.retryFrom});

  final AppFailure failure;
  final StudySessionActive? retryFrom;
}
