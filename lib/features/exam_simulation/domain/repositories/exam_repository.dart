import '../../../../core/error/result.dart';
import '../../../../core/network/paginated.dart';
import '../entities/exam_attempt.dart';
import '../entities/exam_config.dart';

/// The mobile app's only window onto exam attempts (contract §A4). Every
/// call that changes an attempt returns the whole attempt as the server now
/// has it.
abstract class ExamRepository {
  Future<Result<ExamAttempt>> startExam(ExamConfig config);

  Future<Result<ExamAttempt>> getAttempt(String attemptId);

  /// Newest first.
  Future<Result<Paginated<ExamAttemptSummary>>> listAttempts({
    int page = 1,
    int limit = 20,
  });

  /// Records the student's choice. [timeSpentSeconds] is *added* to the
  /// question's stored total.
  Future<Result<ExamAttempt>> answerQuestion({
    required String attemptId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  });

  Future<Result<ExamAttempt>> flagQuestion({
    required String attemptId,
    required String questionId,
    required bool flagged,
  });

  /// Idempotent: submitting a finished attempt returns it as it is — an
  /// expired one comes back `EXPIRED`.
  Future<Result<ExamAttempt>> submitExam(String attemptId);
}
