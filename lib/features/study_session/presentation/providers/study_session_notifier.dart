import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../data/repositories/study_session_repository_impl.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_session_repository.dart';
import 'study_session_state.dart';

/// Owns the Study Session lifecycle against the server (contract §A3):
/// starting or reopening a session, recording every answer and flag as it
/// happens, pause/resume, and completion. Screens only read
/// [StudySessionState] and call these methods.
class StudySessionNotifier extends Notifier<StudySessionState> {
  late final StudySessionRepository _repository;
  Timer? _timer;

  /// Kept so [retry] can restart a session whose first load failed.
  SessionConfig? _lastAttemptedConfig;
  String? _lastReopenedSessionId;

  /// Seconds spent on each question since its last answer call — sent with
  /// the next answer, since the server *adds* `timeSpentSeconds`.
  final Map<String, int> _unsentSeconds = {};

  @override
  StudySessionState build() {
    _repository = ref.watch(studySessionRepositoryProvider);
    ref.onDispose(() => _timer?.cancel());
    return const StudySessionInitial();
  }

  Future<void> startSession(SessionConfig config) async {
    _timer?.cancel();
    _lastAttemptedConfig = config;
    _lastReopenedSessionId = null;
    state = const StudySessionLoading();
    final result = await _repository.startSession(config);
    switch (result) {
      case Success(value: final session):
        _activate(config, session);
      case Failure(:final failure):
        state = StudySessionError(failure: failure);
    }
  }

  /// Reopens an unfinished session (or shows the result of one that turns
  /// out to be completed). A paused session is resumed on the server.
  Future<void> reopenSession(String sessionId) async {
    _timer?.cancel();
    _lastAttemptedConfig = null;
    _lastReopenedSessionId = sessionId;
    state = const StudySessionLoading();
    var result = await _repository.getSession(sessionId);
    if (result case Success(value: final session)
        when session.status == StudySessionStatus.paused) {
      result = await _repository.resumeSession(sessionId);
    }
    switch (result) {
      case Success(value: final session):
        final config = _configFor(session);
        if (session.isCompleted) {
          state = _completed(config, session);
        } else {
          _activate(config, session);
        }
      case Failure(:final failure):
        state = StudySessionError(failure: failure);
    }
  }

  /// A session reopened from the server has no setup config; rebuild one
  /// from what it carries.
  SessionConfig _configFor(StudySession session) {
    return SessionConfig(
      topicIds: session.topicIds,
      // "Budgeting +2" for several topics, from the questions' own names.
      topicName: switch ({for (final q in session.questions) q.topic.name}
          .toList()) {
        [] => '',
        [final only] => only,
        [final first, ...final rest] => '$first +${rest.length}',
      },
      questionCount: session.requestedCount,
      feedbackMode: session.feedbackMode,
    );
  }

  void _activate(SessionConfig config, StudySession session) {
    _unsentSeconds.clear();
    final firstOpen = session.questions.indexWhere((q) => !q.isAnswered);
    state = StudySessionActive(
      config: config,
      session: session,
      currentIndex: firstOpen < 0 ? 0 : firstOpen,
      elapsed: Duration(
        seconds: session.questions.fold(
          0,
          (sum, q) => sum + q.timeSpentSeconds,
        ),
      ),
      isPaused: false,
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current is StudySessionActive && !current.isPaused) {
        final questionId = current.currentQuestion.id;
        _unsentSeconds[questionId] = (_unsentSeconds[questionId] ?? 0) + 1;
        state = current.copyWith(
          elapsed: current.elapsed + const Duration(seconds: 1),
        );
      }
    });
  }

  /// Pauses or resumes, on the server too. Returns `false` when resuming
  /// failed — the session stays paused (the server would reject answers).
  Future<bool> togglePause() async {
    final current = state;
    if (current is! StudySessionActive) return false;
    if (!current.isPaused) {
      state = current.copyWith(isPaused: true);
      final result = await _repository.pauseSession(current.sessionId);
      _applySession(result);
      return true;
    }
    final result = await _repository.resumeSession(current.sessionId);
    if (result is Failure<StudySession>) return false;
    _applySession(result);
    final latest = state;
    if (latest is StudySessionActive) {
      state = latest.copyWith(isPaused: false);
    }
    return true;
  }

  /// Picks a choice for the current question. In "feedback at end" mode
  /// the answer is sent right away; in immediate mode it waits for
  /// [submitCurrentAnswer]. Returns `false` when sending failed.
  Future<bool> selectChoice(String choiceId) async {
    final current = state;
    if (current is! StudySessionActive || current.isPaused) return false;
    if (current.isCurrentLocked || current.isSubmittingAnswer) return false;
    final questionId = current.currentQuestion.id;
    state = current.copyWith(
      draftChoices: {...current.draftChoices, questionId: choiceId},
    );
    if (current.config.feedbackMode == FeedbackMode.immediate) return true;
    return _sendAnswer(questionId, choiceId);
  }

  /// Immediate mode: sends the selected choice; the returned session
  /// reveals it.
  Future<bool> submitCurrentAnswer() async {
    final current = state;
    if (current is! StudySessionActive) return false;
    if (current.config.feedbackMode != FeedbackMode.immediate) return false;
    final questionId = current.currentQuestion.id;
    final choiceId = current.draftChoices[questionId];
    if (choiceId == null || current.isSubmittingAnswer) return false;
    return _sendAnswer(questionId, choiceId);
  }

  Future<bool> _sendAnswer(String questionId, String choiceId) async {
    final current = state;
    if (current is! StudySessionActive) return false;
    state = current.copyWith(isSubmittingAnswer: true);
    final seconds = _unsentSeconds.remove(questionId) ?? 0;
    final result = await _repository.answerQuestion(
      sessionId: current.sessionId,
      questionId: questionId,
      choiceId: choiceId,
      timeSpentSeconds: seconds,
    );
    final latest = state;
    if (latest is! StudySessionActive) return result is Success;
    switch (result) {
      case Success(value: final session):
        final drafts = Map<String, String>.from(latest.draftChoices);
        // A newer pick made while this call was in flight stays a draft.
        if (drafts[questionId] == choiceId) drafts.remove(questionId);
        state = latest.copyWith(
          session: session,
          draftChoices: drafts,
          isSubmittingAnswer: false,
        );
        return true;
      case Failure():
        _unsentSeconds[questionId] =
            (_unsentSeconds[questionId] ?? 0) + seconds;
        final drafts = Map<String, String>.from(latest.draftChoices);
        // In "at end" mode, fall back to what the server has recorded.
        if (latest.config.feedbackMode == FeedbackMode.atEnd) {
          drafts.remove(questionId);
        }
        state = latest.copyWith(
          draftChoices: drafts,
          isSubmittingAnswer: false,
        );
        return false;
    }
  }

  /// Flags or unflags the current question on the server. Returns `false`
  /// when that failed.
  Future<bool> toggleFlag() async {
    final current = state;
    if (current is! StudySessionActive) return false;
    final result = await _repository.flagQuestion(
      sessionId: current.sessionId,
      questionId: current.currentQuestion.id,
      flagged: !current.isCurrentFlagged,
    );
    _applySession(result);
    return result is Success;
  }

  void _applySession(Result<StudySession> result) {
    final latest = state;
    if (result case Success(value: final session)
        when latest is StudySessionActive) {
      state = latest.copyWith(session: session);
    }
  }

  void nextQuestion() => goToQuestion(_index + 1);

  void previousQuestion() => goToQuestion(_index - 1);

  int get _index {
    final current = state;
    return current is StudySessionActive ? current.currentIndex : 0;
  }

  /// Jumps directly to a question — also used by Submission Review's
  /// unanswered list.
  void goToQuestion(int index) {
    final current = state;
    if (current is! StudySessionActive) return;
    if (index < 0 || index >= current.totalQuestions) return;
    state = current.copyWith(currentIndex: index);
  }

  /// Completes the session. Answers are already on the server; an
  /// immediate-mode choice never checked counts as skipped. Safe to call
  /// again after a failure.
  Future<void> submitSession() async {
    final current = state;
    if (current is! StudySessionActive) return;
    _timer?.cancel();
    state = StudySessionSubmitting(current);
    final result = await _repository.completeSession(current.sessionId);
    switch (result) {
      case Success(value: final session):
        state = _completed(current.config, session);
        ref.invalidate(unfinishedStudySessionsProvider);
      case Failure(:final failure):
        state = StudySessionError(failure: failure, retryFrom: current);
    }
  }

  StudySessionCompleted _completed(
    SessionConfig config,
    StudySession session,
  ) => StudySessionCompleted(
    config: config,
    session: session,
    result: session.toResult(),
    review: session.toReview(),
  );

  /// Recovers from [StudySessionError]: back to the preserved session (a
  /// failed completion), or repeats the failed start/reopen.
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
    final lastSessionId = _lastReopenedSessionId;
    if (lastConfig != null) {
      await startSession(lastConfig);
    } else if (lastSessionId != null) {
      await reopenSession(lastSessionId);
    }
  }

  /// Leaves the session on this screen. It stays open on the server and can
  /// be reopened later (see unfinishedStudySessionsProvider).
  void reset() {
    _timer?.cancel();
    _unsentSeconds.clear();
    state = const StudySessionInitial();
    ref.invalidate(unfinishedStudySessionsProvider);
  }
}

final studySessionNotifierProvider =
    NotifierProvider<StudySessionNotifier, StudySessionState>(
      StudySessionNotifier.new,
    );

/// The student's study sessions that aren't completed, newest first — for
/// "continue where you left off" (contract §A3/§A8 B4).
final unfinishedStudySessionsProvider =
    FutureProvider.autoDispose<List<StudySessionSummary>>((ref) async {
      final result = await ref
          .watch(studySessionRepositoryProvider)
          .listSessions(page: 1, limit: 20);
      return switch (result) {
        Success(:final value) => [
          for (final session in value.items)
            if (!session.isCompleted) session,
        ],
        Failure(:final failure) => throw failure,
      };
    });
