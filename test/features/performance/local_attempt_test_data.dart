import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_result.dart';
import 'package:mobile/features/performance/data/models/local_attempt_record.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/session_result.dart';

/// Shared builders for Phase 13 (connected practice loop) tests.

const varianceConfig = SessionConfig(
  topicId: 'topic-variance-analysis',
  topicName: 'Variance Analysis',
  questionCount: 10,
  feedbackMode: FeedbackMode.atEnd,
);

/// 10 questions, 9 answered, 3 correct, 6 wrong, 45s — the same attempt
/// verified live on the simulator.
const varianceResult = SessionResult(
  sessionId: 'mock-session-0',
  totalQuestions: 10,
  answered: 9,
  unanswered: 1,
  correct: 3,
  incorrect: 6,
  scorePercent: 30,
  totalTime: Duration(seconds: 45),
  averageTimePerQuestion: Duration(seconds: 4),
);

const cmaPart2Config = ExamConfig(
  programId: 'program-cma',
  programName: 'CMA',
  partId: 'part-cma-2',
  partName: 'Part 2',
  questionCount: 25,
  duration: Duration(minutes: 30),
);

const cmaPart2Result = ExamResult(
  attemptId: 'mock-attempt-0',
  totalQuestions: 25,
  answered: 8,
  unanswered: 17,
  correct: 2,
  incorrect: 6,
  scorePercent: 8,
  durationTaken: Duration(seconds: 41),
  completionStatus: 'COMPLETED',
);

/// A study-session record on [topicId] with the given counts.
LocalAttemptRecord studyRecord({
  String id = 'local-s-1',
  DateTime? completedAt,
  String topicId = 'topic-variance-analysis',
  String topicName = 'Variance Analysis',
  int total = 10,
  int answered = 9,
  int correct = 3,
  int avgSeconds = 4,
}) {
  return LocalAttemptRecord(
    attemptId: id,
    sourceId: 'mock-session-0',
    type: AttemptType.studySession,
    completedAt: completedAt ?? DateTime(2026, 10, 4, 19, 6),
    contentLabel: topicName,
    totalQuestions: total,
    answered: answered,
    unanswered: total - answered,
    correct: correct,
    wrong: answered - correct,
    scorePercent: total == 0 ? 0 : correct / total * 100,
    durationSeconds: avgSeconds * total,
    averageTimePerQuestionSeconds: avgSeconds,
    topicId: topicId,
    topicName: topicName,
  );
}

LocalAttemptRecord examRecord({
  String id = 'local-e-1',
  DateTime? completedAt,
}) {
  return LocalAttemptRecord(
    attemptId: id,
    sourceId: 'mock-attempt-0',
    type: AttemptType.examSimulation,
    completedAt: completedAt ?? DateTime(2026, 10, 4, 19, 9),
    contentLabel: 'CMA Part 2',
    totalQuestions: 25,
    answered: 8,
    unanswered: 17,
    correct: 2,
    wrong: 6,
    scorePercent: 8,
    durationSeconds: 41,
    averageTimePerQuestionSeconds: 1,
  );
}
