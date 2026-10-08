import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/exam_simulation/presentation/providers/exam_notifier.dart';
import '../features/exam_simulation/presentation/providers/exam_state.dart';
import '../features/performance/data/datasources/performance_data_source.dart';
import '../features/performance/data/local_attempts_provider.dart';
import '../features/performance/data/mappers/exam_result_mapper.dart';
import '../features/performance/data/mappers/session_result_mapper.dart';
import '../features/performance/data/models/local_attempt_record.dart';
import '../features/study_session/presentation/providers/study_session_notifier.dart';
import '../features/study_session/presentation/providers/study_session_state.dart';

/// When a completed attempt happened — a provider only so tests can pin
/// it. Neither SessionResult nor ExamResult carries a timestamp.
final practiceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The composition-layer bridge between the practice flows and
/// Performance: Study Session and Exam Simulation never know Performance
/// exists, and Performance never reads their notifiers — this file (in
/// `app/`, which already composes features, like Home and the router) is
/// the only place that connects them.
///
/// Records one [LocalAttemptRecord] each time either notifier *transitions
/// into* its completed state — never for errors, resets, or in-progress
/// states, and never twice for one completion. A timed-out exam records
/// too, since it still reaches [ExamCompleted].
///
/// Only while the Performance API is unavailable: with a real backend the
/// practice submit endpoints record attempts server-side, so recording
/// here as well would double-count every attempt.
///
/// Kept alive for the app's lifetime by app/app.dart.
final practiceAttemptRecorderProvider = Provider<void>((ref) {
  void record(LocalAttemptRecord Function(DateTime completedAt) build) {
    if (ref.read(performanceApiAvailableProvider)) return;
    final completedAt = ref.read(practiceClockProvider)();
    ref.read(localAttemptsProvider.notifier).record(build(completedAt));
  }

  ref.listen<StudySessionState>(studySessionNotifierProvider, (previous, next) {
    if (next is! StudySessionCompleted || previous is StudySessionCompleted) {
      return;
    }
    record(
      (completedAt) => localAttemptRecordFromSessionResult(
        result: next.result,
        config: next.config,
        completedAt: completedAt,
      ),
    );
  });

  ref.listen<ExamState>(examNotifierProvider, (previous, next) {
    if (next is! ExamCompleted || previous is ExamCompleted) return;
    record(
      (completedAt) => localAttemptRecordFromExamResult(
        result: next.result,
        config: next.config,
        completedAt: completedAt,
        review: next.review,
      ),
    );
  });
});
