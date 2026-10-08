import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/result.dart';
import '../../data/repositories/exam_repository_impl.dart';
import '../../domain/entities/exam_attempt.dart';
import '../../domain/entities/exam_config.dart';
import '../../domain/repositories/exam_repository.dart';
import 'exam_state.dart';

/// The clock the countdown reads — a provider so tests can drive it.
final examClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Owns the Exam Simulation lifecycle against the server (contract §A4):
/// starting or reopening an attempt, saving every answer and flag as it
/// happens, the countdown (the server owns the clock), and submission —
/// including the automatic one when time runs out.
class ExamNotifier extends Notifier<ExamState> {
  late final ExamRepository _repository;
  late final DateTime Function() _now;
  Timer? _timer;
  ExamConfig? _lastAttemptedConfig;
  String? _lastReopenedAttemptId;

  /// When the attempt ends, on this device's clock: now + the server's
  /// `remainingSeconds`, re-based on every response. Device-clock skew
  /// against the server doesn't matter this way.
  DateTime? _deadline;

  /// Seconds spent on each question since its last answer call.
  final Map<String, int> _unsentSeconds = {};

  @override
  ExamState build() {
    _repository = ref.watch(examRepositoryProvider);
    _now = ref.watch(examClockProvider);
    ref.onDispose(() => _timer?.cancel());
    return const ExamInitial();
  }

  Future<void> startExam(ExamConfig config) async {
    _timer?.cancel();
    _lastAttemptedConfig = config;
    _lastReopenedAttemptId = null;
    state = const ExamLoading();
    final result = await _repository.startExam(config);
    switch (result) {
      case Success(value: final attempt):
        _open(config, attempt);
      case Failure(:final failure):
        state = ExamError(failure: failure);
    }
  }

  /// Reopens an unfinished attempt — or shows the result of one that
  /// finished (or expired) in the meantime.
  Future<void> reopenAttempt(String attemptId) async {
    _timer?.cancel();
    _lastAttemptedConfig = null;
    _lastReopenedAttemptId = attemptId;
    state = const ExamLoading();
    final result = await _repository.getAttempt(attemptId);
    switch (result) {
      case Success(value: final attempt):
        _open(_configFor(attempt), attempt);
      case Failure(:final failure):
        state = ExamError(failure: failure);
    }
  }

  /// An attempt reopened from the server has no setup config; rebuild one
  /// from what it carries.
  ExamConfig _configFor(ExamAttempt attempt) => ExamConfig(
    programId: '',
    programName: '',
    partId: '',
    partName: '',
    questionCount: attempt.requestedCount,
    duration: Duration(minutes: attempt.durationMinutes),
    topicIds: attempt.topicIds,
  );

  void _open(ExamConfig config, ExamAttempt attempt) {
    if (!attempt.isInProgress) {
      state = _completed(config, attempt);
      return;
    }
    if (attempt.questions.isEmpty) {
      state = const ExamError(
        failure: ValidationFailure(
          'No published questions match the selection criteria',
        ),
      );
      return;
    }
    _unsentSeconds.clear();
    _deadline = _now().add(Duration(seconds: attempt.remainingSeconds));
    final firstOpen = attempt.questions.indexWhere((q) => !q.isAnswered);
    state = ExamActive(
      config: config,
      attempt: attempt,
      currentIndex: firstOpen < 0 ? 0 : firstOpen,
      remainingSeconds: attempt.remainingSeconds,
    );
    _startTimer();
  }

  int _secondsLeft() {
    final deadline = _deadline;
    if (deadline == null) return 0;
    final left = deadline.difference(_now()).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current is! ExamActive) {
      _timer?.cancel();
      return;
    }
    final questionId = current.currentQuestion.id;
    _unsentSeconds[questionId] = (_unsentSeconds[questionId] ?? 0) + 1;
    final left = _secondsLeft();
    if (left <= 0) {
      _timer?.cancel();
      final expired = current.copyWith(remainingSeconds: 0);
      state = ExamTimedOut(expired);
      // Submitted anyway: the server answers with the attempt as EXPIRED.
      unawaited(_doSubmit(expired, isTimeout: true));
      return;
    }
    state = current.copyWith(remainingSeconds: left);
  }

  /// Re-reads the attempt and re-bases the countdown — after the app
  /// returns from the background, or when a save was rejected. An attempt
  /// that ended meanwhile goes straight to its result.
  Future<void> resync() async {
    final current = state;
    if (current is! ExamActive) return;
    final result = await _repository.getAttempt(current.attemptId);
    final latest = state;
    if (result case Success(value: final attempt)
        when latest is ExamActive && latest.attemptId == attempt.id) {
      if (!attempt.isInProgress) {
        _timer?.cancel();
        state = _completed(latest.config, attempt);
        return;
      }
      _applyAttempt(latest, attempt);
    }
  }

  void _applyAttempt(ExamActive current, ExamAttempt attempt) {
    _deadline = _now().add(Duration(seconds: attempt.remainingSeconds));
    state = current.copyWith(
      attempt: attempt,
      remainingSeconds: attempt.remainingSeconds,
    );
  }

  bool get _isInteractive {
    final current = state;
    return current is ExamActive && current.remainingSeconds > 0;
  }

  /// Saves the choice for the current question right away. Returns `false`
  /// when it couldn't be saved (the previous answer is shown again).
  Future<bool> selectChoice(String choiceId) async {
    final current = state;
    if (current is! ExamActive || !_isInteractive) return false;
    final questionId = current.currentQuestion.id;
    state = current.copyWith(
      draftChoices: {...current.draftChoices, questionId: choiceId},
    );
    final seconds = _unsentSeconds.remove(questionId) ?? 0;
    final result = await _repository.answerQuestion(
      attemptId: current.attemptId,
      questionId: questionId,
      choiceId: choiceId,
      timeSpentSeconds: seconds,
    );
    final latest = state;
    if (latest is! ExamActive) return result is Success;
    final drafts = Map<String, String>.from(latest.draftChoices);
    if (drafts[questionId] == choiceId) drafts.remove(questionId);
    switch (result) {
      case Success(value: final attempt):
        if (!attempt.isInProgress) {
          _timer?.cancel();
          state = _completed(latest.config, attempt);
          return false;
        }
        _applyAttempt(latest.copyWith(draftChoices: drafts), attempt);
        return true;
      case Failure(:final failure):
        _unsentSeconds[questionId] =
            (_unsentSeconds[questionId] ?? 0) + seconds;
        state = latest.copyWith(draftChoices: drafts);
        // A 400 here usually means the attempt is no longer in progress.
        if (failure is ValidationFailure) await resync();
        return false;
    }
  }

  /// Flags or unflags the current question on the server. Returns `false`
  /// when that failed.
  Future<bool> toggleFlag() async {
    final current = state;
    if (current is! ExamActive || !_isInteractive) return false;
    final result = await _repository.flagQuestion(
      attemptId: current.attemptId,
      questionId: current.currentQuestion.id,
      flagged: !current.isCurrentFlagged,
    );
    final latest = state;
    switch (result) {
      case Success(value: final attempt) when latest is ExamActive:
        _applyAttempt(latest, attempt);
        return true;
      case Failure(:final failure):
        if (failure is ValidationFailure) await resync();
        return false;
      default:
        return false;
    }
  }

  ExamActive? get currentActive {
    final current = state;
    return current is ExamActive ? current : null;
  }

  void nextQuestion() => goToQuestion((currentActive?.currentIndex ?? 0) + 1);

  void previousQuestion() =>
      goToQuestion((currentActive?.currentIndex ?? 0) - 1);

  void goToQuestion(int index) {
    final current = state;
    if (current is! ExamActive) return;
    if (index < 0 || index >= current.totalQuestions) return;
    state = current.copyWith(currentIndex: index);
  }

  Future<void> submitExam() async {
    final current = state;
    if (current is! ExamActive) return;
    await _doSubmit(current, isTimeout: false);
  }

  Future<void> _doSubmit(ExamActive active, {required bool isTimeout}) async {
    _timer?.cancel();
    state = ExamSubmitting(active, isTimeoutSubmission: isTimeout);
    final result = await _repository.submitExam(active.attemptId);
    switch (result) {
      case Success(value: final attempt):
        state = _completed(active.config, attempt);
      case Failure(:final failure):
        state = ExamError(
          failure: failure,
          retryFrom: active,
          wasTimeout: isTimeout,
        );
    }
  }

  ExamCompleted _completed(ExamConfig config, ExamAttempt attempt) {
    ref.invalidate(unfinishedExamAttemptsProvider);
    return ExamCompleted(
      config: config,
      attempt: attempt,
      result: attempt.toResult(),
      review: attempt.toReview(),
    );
  }

  /// Recovers from [ExamError]: a failed submission is sent again (submit
  /// is idempotent) or the attempt resumes; a failed start/reopen repeats.
  Future<void> retry() async {
    final current = state;
    if (current is! ExamError) return;
    final retryFrom = current.retryFrom;
    if (retryFrom == null) {
      final lastConfig = _lastAttemptedConfig;
      final lastAttemptId = _lastReopenedAttemptId;
      if (lastConfig != null) {
        await startExam(lastConfig);
      } else if (lastAttemptId != null) {
        await reopenAttempt(lastAttemptId);
      }
      return;
    }
    if (current.wasTimeout || _secondsLeft() <= 0) {
      state = ExamTimedOut(retryFrom);
      await _doSubmit(retryFrom, isTimeout: true);
      return;
    }
    state = retryFrom.copyWith(remainingSeconds: _secondsLeft());
    _startTimer();
  }

  /// Leaves the attempt on this screen. Its clock keeps running on the
  /// server; it can be reopened until it expires.
  void reset() {
    _timer?.cancel();
    _unsentSeconds.clear();
    _deadline = null;
    state = const ExamInitial();
    ref.invalidate(unfinishedExamAttemptsProvider);
  }
}

final examNotifierProvider = NotifierProvider<ExamNotifier, ExamState>(
  ExamNotifier.new,
);

/// The student's exam attempts that are still running, newest first — for
/// "continue your exam" (contract §A8 B4).
final unfinishedExamAttemptsProvider =
    FutureProvider.autoDispose<List<ExamAttemptSummary>>((ref) async {
      final now = ref.watch(examClockProvider)().toUtc();
      final result = await ref
          .watch(examRepositoryProvider)
          .listAttempts(page: 1, limit: 20);
      return switch (result) {
        Success(:final value) => [
          for (final attempt in value.items)
            if (attempt.isOpenAt(now)) attempt,
        ],
        Failure(:final failure) => throw failure,
      };
    });
