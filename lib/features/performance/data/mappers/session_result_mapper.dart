import '../../../study_session/domain/entities/session_config.dart';
import '../../../study_session/domain/entities/session_result.dart';
import '../../domain/entities/attempt_summary.dart';
import '../../domain/entities/attempt_type.dart';
import '../models/local_attempt_record.dart';

/// Adapter from Study Session's own result shape onto this feature's
/// [AttemptSummary] — the seam ARCHITECTURE.md's "Study Session → Result →
/// Analytics" diagram describes (see this feature's README). A pure
/// mapping function, not a dependency either feature takes on the other at
/// runtime: Performance Analytics reads Study Session's *entities* here
/// (already public, already the data a backend Performance endpoint would
/// itself be built from), never its notifier or state machine — so
/// analytics stays independent of session execution, per this phase's
/// brief.
AttemptSummary attemptSummaryFromSessionResult({
  required SessionResult result,
  required SessionConfig config,
  required DateTime completedAt,
}) {
  return AttemptSummary(
    attemptId: result.sessionId,
    type: AttemptType.studySession,
    completedAt: completedAt,
    contentLabel: config.topicName,
    totalQuestions: result.totalQuestions,
    answered: result.answered,
    correct: result.correct,
    scorePercent: result.scorePercent,
    duration: result.totalTime,
  );
}

/// The full local record of a completed Study Session — summary fields via
/// [attemptSummaryFromSessionResult] (one mapping, not two), plus what
/// Attempt Details and topic aggregation need. The session is always about
/// exactly one Curriculum topic ([SessionConfig.topicId]).
LocalAttemptRecord localAttemptRecordFromSessionResult({
  required SessionResult result,
  required SessionConfig config,
  required DateTime completedAt,
}) {
  final summary = attemptSummaryFromSessionResult(
    result: result,
    config: config,
    completedAt: completedAt,
  );
  return LocalAttemptRecord(
    attemptId: LocalAttemptRecord.idFor(summary.attemptId, completedAt),
    sourceId: summary.attemptId,
    type: summary.type,
    completedAt: summary.completedAt,
    contentLabel: summary.contentLabel,
    totalQuestions: summary.totalQuestions,
    answered: summary.answered,
    unanswered: result.unanswered,
    correct: summary.correct,
    wrong: result.incorrect,
    scorePercent: summary.scorePercent,
    durationSeconds: summary.duration.inSeconds,
    averageTimePerQuestionSeconds: result.averageTimePerQuestion.inSeconds,
    topicId: config.topicId,
    topicName: config.topicName,
  );
}
