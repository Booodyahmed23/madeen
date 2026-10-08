import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/repositories/study_session_repository.dart';
import '../../data/repositories/study_session_repository_impl.dart';
import 'study_session_state.dart';

/// Owns the whole Study Session lifecycle: starting a session, navigating
/// between questions, recording answers, immediate-feedback submission, the
/// count-up timer, and final submission. Business logic lives entirely here
/// — screens only read [StudySessionState] and call these methods, never
/// the repository directly.
class StudySessionNotifier extends Notifier<StudySessionState> {
  late final StudySessionRepository _repository;
  Timer? _timer;

  /// Kept only so [retry] can restart a session whose *first* load failed
  /// (before any [StudySessionActive] snapshot existed to fall back to).
  /// Not part of the public state — purely internal retry bookkeeping.
  SessionConfig? _lastAttemptedConfig;

  @override
  StudySessionState build() {
    _repository = ref.watch(studySessionRepositoryProvider);
    ref.onDispose(() => _timer?.cancel());
    return const StudySessionInitial();
  }

  Future<void> startSession(SessionConfig config) async {
    _timer?.cancel();
    _lastAttemptedConfig = config;
    state = const StudySessionLoading();

    final result = await _repository.startSession(config);
    result.when(
      success: (bundle) {
        // Per STUDY_SESSION_API_REQUIREMENTS.md, an empty question set is a
        // valid response (a topic with no content yet), not an error — but
        // there is no "current question" to show, so this never becomes
        // StudySessionActive (every field on it assumes at least one
        // question exists).
        if (bundle.questions.isEmpty) {
          state = const StudySessionError(
            failure: ValidationFailure(
              'No questions are available for this topic yet.',
            ),
          );
          return;
        }
        state = StudySessionActive(
          config: config,
          sessionId: bundle.sessionId,
          questions: bundle.questions,
          currentIndex: 0,
          selectedAnswers: const {},
          answeredQuestionIds: const {},
          feedbackByQuestion: const {},
          phase: QuestionPhase.ready,
          elapsed: Duration.zero,
          isPaused: false,
        );
        _startTimer();
      },
      failure: (failure) => state = StudySessionError(failure: failure),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current is StudySessionActive && !current.isPaused) {
        state = current.copyWith(
          elapsed: current.elapsed + const Duration(seconds: 1),
        );
      }
    });
  }

  /// No-op when the session isn't active — e.g. a stray tap while a
  /// submission is already in flight.
  void togglePause() {
    final current = state;
    if (current is StudySessionActive) {
      state = current.copyWith(isPaused: !current.isPaused);
    }
  }

  void selectChoice(String choiceId) {
    final current = state;
    if (current is! StudySessionActive) return;
    // Locked once immediate feedback has been shown for this question —
    // the correct answer is already visible, changing the choice now would
    // be meaningless and could desync from what was scored server-side.
    if (current.phase == QuestionPhase.feedback) return;

    final updated = Map<String, String>.from(current.selectedAnswers)
      ..[current.currentQuestion.id] = choiceId;
    state = current.copyWith(
      selectedAnswers: updated,
      phase: QuestionPhase.answering,
    );
  }

  /// Immediate-feedback mode only. Returns whether it succeeded so the
  /// screen can show a retry affordance on failure without that transient
  /// error living in shared state.
  Future<bool> submitCurrentAnswer() async {
    final current = state;
    if (current is! StudySessionActive) return false;
    if (current.config.feedbackMode != FeedbackMode.immediate) return false;
    final selected = current.selectedChoiceForCurrent;
    if (selected == null) return false;

    state = current.copyWith(isSubmittingAnswer: true);
    final result = await _repository.submitAnswer(
      sessionId: current.sessionId,
      questionId: current.currentQuestion.id,
      selectedChoiceId: selected,
    );

    return result.when(
      success: (feedback) {
        final latest = state;
        if (latest is! StudySessionActive) return true;
        state = latest.copyWith(
          feedbackByQuestion: {
            ...latest.feedbackByQuestion,
            feedback.questionId: feedback,
          },
          answeredQuestionIds: {
            ...latest.answeredQuestionIds,
            feedback.questionId,
          },
          phase: QuestionPhase.feedback,
          isSubmittingAnswer: false,
        );
        return true;
      },
      failure: (failure) {
        final latest = state;
        if (latest is StudySessionActive) {
          state = latest.copyWith(isSubmittingAnswer: false);
        }
        return false;
      },
    );
  }

  void nextQuestion() => _moveBy(1);

  void previousQuestion() => _moveBy(-1);

  /// Jumps directly to a question — used by the unanswered-question review
  /// list on the Submission Review screen.
  void goToQuestion(int index) {
    final current = state;
    if (current is! StudySessionActive) return;
    if (index < 0 || index >= current.totalQuestions) return;
    state = current.copyWith(
      currentIndex: index,
      phase: _phaseFor(current, index),
    );
  }

  void _moveBy(int delta) {
    final current = state;
    if (current is! StudySessionActive) return;
    final newIndex = current.currentIndex + delta;
    if (newIndex < 0 || newIndex >= current.totalQuestions) return;
    state = current.copyWith(
      currentIndex: newIndex,
      phase: _phaseFor(current, newIndex),
    );
  }

  QuestionPhase _phaseFor(StudySessionActive current, int index) {
    final questionId = current.questions[index].id;
    if (current.config.feedbackMode == FeedbackMode.immediate &&
        current.answeredQuestionIds.contains(questionId)) {
      return QuestionPhase.feedback;
    }
    if (current.selectedAnswers.containsKey(questionId)) {
      return QuestionPhase.answering;
    }
    return QuestionPhase.ready;
  }

  /// Finalizes the session. Always safe to call again after a failure —
  /// [StudySessionError.retryFrom] preserves every answer already made, and
  /// submitSession on the backend/mock is treated as idempotent.
  Future<void> submitSession() async {
    final current = state;
    if (current is! StudySessionActive) return;
    _timer?.cancel();
    state = StudySessionSubmitting(current);

    final answers = <String, String?>{
      for (final question in current.questions)
        question.id: current.selectedAnswers[question.id],
    };

    final result = await _repository.submitSession(
      sessionId: current.sessionId,
      answers: answers,
      totalTime: current.elapsed,
    );

    await result.when(
      success: (sessionResult) async {
        final reviewResult = await _repository.getReview(current.sessionId);
        state = reviewResult.when(
          success: (review) => StudySessionCompleted(
            config: current.config,
            result: sessionResult,
            review: review,
          ),
          // The session itself was already submitted and scored — losing
          // the review fetch must not look like the submission failed, or
          // a retry would double-submit. Show results with an empty
          // review rather than drop the (already-authoritative) score.
          failure: (_) => StudySessionCompleted(
            config: current.config,
            result: sessionResult,
            review: const [],
          ),
        );
      },
      failure: (failure) async {
        state = StudySessionError(failure: failure, retryFrom: current);
      },
    );
  }

  /// Resumes from [StudySessionError]: restores the preserved session if
  /// one exists (a failed submit), otherwise retries the original
  /// [startSession] call (a failed session start had nothing to restore).
  Future<void> retry() async {
    final current = state;
    if (current is! StudySessionError) return;

    final retryFrom = current.retryFrom;
    if (retryFrom != null) {
      state = retryFrom;
      _startTimer();
      return;
    }

    final lastConfig = _lastAttemptedConfig;
    if (lastConfig != null) {
      await startSession(lastConfig);
    }
  }

  /// Abandons the current session entirely (student confirmed leaving).
  void reset() {
    _timer?.cancel();
    state = const StudySessionInitial();
  }
}

final studySessionNotifierProvider =
    NotifierProvider<StudySessionNotifier, StudySessionState>(
      StudySessionNotifier.new,
    );
