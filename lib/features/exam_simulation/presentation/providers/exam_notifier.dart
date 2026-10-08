import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../data/repositories/exam_repository_impl.dart';
import '../../domain/entities/exam_config.dart';
import '../../domain/repositories/exam_repository.dart';
import 'exam_state.dart';

/// Owns the whole Exam Simulation lifecycle: starting an attempt,
/// navigating between questions, recording answers, flagging, the
/// countdown timer (including auto-submission on timeout), and final
/// submission. Business logic lives entirely here — screens only read
/// [ExamState] and call these methods, never the repository directly.
///
/// ## Timer architecture
/// A single `Timer.periodic` lives on this Notifier instance (not in any
/// widget's `build()`), started once per attempt and cancelled exactly
/// once — on timeout, on manual submission, on reset, and via
/// `ref.onDispose`. Because Riverpod's provider container is not tied to
/// any one screen's widget lifecycle, this timer keeps ticking correctly
/// across widget rebuilds and across the student navigating between
/// questions; reopening the active-exam screen (e.g. after briefly
/// backgrounding the app) reads the *same* running timer rather than
/// restarting it.
///
/// **Known limitation** (documented in EXAM_SIMULATION_API_REQUIREMENTS.md
/// too): this is still an in-memory, client-side clock. It does not
/// survive the app process being killed (there is no local persistence of
/// an in-progress attempt this phase), and OS-level background execution
/// limits can throttle a `Timer` while backgrounded, so the countdown is
/// not wall-clock-exact across a long backgrounding. Production behavior
/// (rejecting a submission after the server's own deadline, or reconciling
/// elapsed time from server timestamps) requires the backend to be
/// authoritative for expiry — this client timer is a UX countdown, not the
/// security boundary.
class ExamNotifier extends Notifier<ExamState> {
  late final ExamRepository _repository;
  Timer? _timer;

  /// Kept only so [retry] can restart an exam whose *first* load failed
  /// (before any [ExamActive] snapshot existed to fall back to). Not part
  /// of the public state — purely internal retry bookkeeping.
  ExamConfig? _lastAttemptedConfig;

  @override
  ExamState build() {
    _repository = ref.watch(examRepositoryProvider);
    ref.onDispose(() => _timer?.cancel());
    return const ExamInitial();
  }

  Future<void> startExam(ExamConfig config) async {
    _timer?.cancel();
    _lastAttemptedConfig = config;
    state = const ExamLoading();

    final result = await _repository.startExam(config);
    result.when(
      success: (attempt) {
        // A topic/config with no content yet is a valid response, not an
        // error — but there is no "current question" to show (mirrors the
        // same guard in study_session's notifier, and the same crash this
        // phase's own tests reproduced there).
        if (attempt.questions.isEmpty) {
          state = const ExamError(
            failure: ValidationFailure(
              'No questions are available for this exam configuration yet.',
            ),
          );
          return;
        }
        state = ExamActive(
          config: config,
          attemptId: attempt.attemptId,
          questions: attempt.questions,
          currentIndex: 0,
          selectedAnswers: const {},
          flaggedQuestionIds: const {},
          totalDurationSeconds: attempt.durationSeconds,
          remainingSeconds: attempt.durationSeconds,
        );
        _startTimer();
      },
      failure: (failure) => state = ExamError(failure: failure),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current is! ExamActive) {
        _timer?.cancel();
        return;
      }
      if (current.remainingSeconds <= 1) {
        _timer?.cancel();
        final expired = current.copyWith(remainingSeconds: 0);
        state = ExamTimedOut(expired);
        unawaited(_doSubmit(expired, isTimeout: true));
        return;
      }
      state = current.copyWith(remainingSeconds: current.remainingSeconds - 1);
    });
  }

  /// No pause button exists in this feature's UI by design (see this
  /// feature's README) — there is deliberately no `togglePause`/`pause`
  /// method here for a screen to call, unlike study_session's notifier.

  void selectChoice(String choiceId) {
    final current = state;
    if (current is! ExamActive) return;
    final updated = Map<String, String>.from(current.selectedAnswers)
      ..[current.currentQuestion.id] = choiceId;
    state = current.copyWith(selectedAnswers: updated);
  }

  void toggleFlag() {
    final current = state;
    if (current is! ExamActive) return;
    final questionId = current.currentQuestion.id;
    final updated = Set<String>.from(current.flaggedQuestionIds);
    if (!updated.remove(questionId)) {
      updated.add(questionId);
    }
    state = current.copyWith(flaggedQuestionIds: updated);
  }

  /// The live in-progress exam, or `null` once it has ended (submitting,
  /// timed out, completed, …) — for UI that must act on the *current*
  /// counts after awaiting something (e.g. a sheet closing).
  ExamActive? get currentActive {
    final current = state;
    return current is ExamActive ? current : null;
  }

  void nextQuestion() => _moveBy(1);

  void previousQuestion() => _moveBy(-1);

  /// Jumps directly to a question — used by the Exam Review screen's
  /// flagged/unanswered navigation chips.
  void goToQuestion(int index) {
    final current = state;
    if (current is! ExamActive) return;
    if (index < 0 || index >= current.totalQuestions) return;
    state = current.copyWith(currentIndex: index);
  }

  void _moveBy(int delta) {
    final current = state;
    if (current is! ExamActive) return;
    final newIndex = current.currentIndex + delta;
    if (newIndex < 0 || newIndex >= current.totalQuestions) return;
    state = current.copyWith(currentIndex: newIndex);
  }

  /// Finalizes the exam. Always safe to call again after a failure —
  /// [ExamError.retryFrom] preserves every answer and flag already made,
  /// and submitExam on the backend/mock is treated as idempotent.
  Future<void> submitExam() async {
    final current = state;
    if (current is! ExamActive) return;
    await _doSubmit(current, isTimeout: false);
  }

  Future<void> _doSubmit(ExamActive active, {required bool isTimeout}) async {
    _timer?.cancel();
    state = ExamSubmitting(active, isTimeoutSubmission: isTimeout);

    final answers = <String, String?>{
      for (final question in active.questions)
        question.id: active.selectedAnswers[question.id],
    };
    final timeTaken = Duration(
      seconds: active.totalDurationSeconds - active.remainingSeconds,
    );

    final result = await _repository.submitExam(
      attemptId: active.attemptId,
      answers: answers,
      flaggedQuestionIds: active.flaggedQuestionIds,
      timeTaken: timeTaken,
    );

    await result.when(
      success: (examResult) async {
        final reviewResult = await _repository.getReview(active.attemptId);
        state = reviewResult.when(
          success: (review) => ExamCompleted(
            config: active.config,
            result: examResult,
            review: review,
          ),
          // The attempt itself was already submitted and scored — losing
          // the review fetch must not look like the submission failed, or
          // a retry would double-submit. Show results with an empty
          // review rather than drop the (already-authoritative) score.
          failure: (_) => ExamCompleted(
            config: active.config,
            result: examResult,
            review: const [],
          ),
        );
      },
      failure: (failure) async {
        state = ExamError(
          failure: failure,
          retryFrom: active,
          wasTimeout: isTimeout,
        );
      },
    );
  }

  /// Resumes from [ExamError]. Three cases:
  /// - a failed *timeout* submission: the exam is already over (0 seconds
  ///   left) — retry re-attempts the submission directly rather than
  ///   handing the student an editable exam with a dead clock.
  /// - a failed *manual* submission: restores [ExamActive] exactly as it
  ///   was and resumes the countdown.
  /// - a failed exam *start*: nothing to restore — retries [startExam]
  ///   with the same config.
  Future<void> retry() async {
    final current = state;
    if (current is! ExamError) return;

    final retryFrom = current.retryFrom;
    if (retryFrom == null) {
      final lastConfig = _lastAttemptedConfig;
      if (lastConfig != null) {
        await startExam(lastConfig);
      }
      return;
    }

    if (current.wasTimeout) {
      state = ExamTimedOut(retryFrom);
      await _doSubmit(retryFrom, isTimeout: true);
      return;
    }

    state = retryFrom;
    _startTimer();
  }

  /// Abandons the current exam entirely (student confirmed leaving).
  void reset() {
    _timer?.cancel();
    state = const ExamInitial();
  }
}

final examNotifierProvider = NotifierProvider<ExamNotifier, ExamState>(
  ExamNotifier.new,
);
