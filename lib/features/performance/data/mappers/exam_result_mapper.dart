import '../../../exam_simulation/domain/entities/exam_config.dart';
import '../../../exam_simulation/domain/entities/exam_result.dart';
import '../../../exam_simulation/domain/entities/exam_review_item.dart';
import '../../../exam_simulation/domain/entities/exam_topic_breakdown.dart';
import '../../domain/entities/attempt_summary.dart';
import '../../domain/entities/attempt_type.dart';
import '../models/local_attempt_record.dart';
import '../models/topic_performance_model.dart';

/// Adapter from Exam Simulation's own result shape onto this feature's
/// [AttemptSummary] — the "Exam Simulation → Result → Analytics" seam,
/// mirroring session_result_mapper.dart exactly. Reads Exam Simulation's
/// public entities only, never its notifier — analytics stays independent
/// of exam execution, per this phase's brief.
AttemptSummary attemptSummaryFromExamResult({
  required ExamResult result,
  required ExamConfig config,
  required DateTime completedAt,
}) {
  return AttemptSummary(
    attemptId: result.attemptId,
    type: AttemptType.examSimulation,
    completedAt: completedAt,
    contentLabel: '${config.programName} ${config.partName}',
    totalQuestions: result.totalQuestions,
    answered: result.answered,
    correct: result.correct,
    scorePercent: result.scorePercent,
    duration: result.durationTaken,
  );
}

/// The full local record of a completed Exam Simulation attempt (including
/// a timed-out one, which still completes) — summary fields via
/// [attemptSummaryFromExamResult], plus one topic row per topic in the
/// post-submission [review] (see [examTopicBreakdown]). Per-topic time is
/// left unknown: the exam only measures time for the attempt as a whole.
LocalAttemptRecord localAttemptRecordFromExamResult({
  required ExamResult result,
  required ExamConfig config,
  required DateTime completedAt,
  List<ExamReviewItem> review = const [],
}) {
  final summary = attemptSummaryFromExamResult(
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
    averageTimePerQuestionSeconds: result.totalQuestions == 0
        ? 0
        : summary.duration.inSeconds ~/ result.totalQuestions,
    topics: [
      for (final topic in examTopicBreakdown(review))
        TopicPerformanceModel(
          topicId: topic.topicId,
          topicName: topic.topicName,
          questionsAttempted: topic.total,
          answered: topic.answered,
          correct: topic.correct,
          wrong: topic.wrong,
        ),
    ],
  );
}
