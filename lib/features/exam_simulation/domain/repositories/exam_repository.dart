import '../../../../core/error/result.dart';
import '../entities/exam_attempt.dart';
import '../entities/exam_config.dart';
import '../entities/exam_result.dart';
import '../entities/exam_review_item.dart';

/// The mobile app's only window onto Exam Simulation data — presentation
/// code depends on this interface, never on a concrete data source (see
/// EXAM_SIMULATION_API_REQUIREMENTS.md at the repo root of mobile/ for the
/// proposed backend contract this mirrors).
abstract class ExamRepository {
  Future<Result<ExamAttempt>> startExam(ExamConfig config);

  /// Reloads an in-progress attempt by id. Not wired into any screen this
  /// phase (there is no persistence layer to reconnect a killed app to a
  /// running attempt id yet — see this feature's README "Known
  /// limitations") but kept on the interface since
  /// EXAM_SIMULATION_API_REQUIREMENTS.md lists it as a required backend
  /// operation and the mock/remote data sources already implement it.
  Future<Result<ExamAttempt>> getAttempt(String attemptId);

  /// Finalizes the attempt and returns the authoritative [ExamResult].
  /// `answers` is the complete question-id → selected-choice-id map (nulls
  /// allowed for unanswered questions); `flaggedQuestionIds` is sent for
  /// the post-exam review only — it never affects scoring.
  Future<Result<ExamResult>> submitExam({
    required String attemptId,
    required Map<String, String?> answers,
    required Set<String> flaggedQuestionIds,
    required Duration timeTaken,
  });

  /// Full per-question review — only meaningful after [submitExam].
  Future<Result<List<ExamReviewItem>>> getReview(String attemptId);
}
