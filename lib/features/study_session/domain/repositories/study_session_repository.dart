import '../../../../core/error/result.dart';
import '../../../../core/network/paginated.dart';
import '../entities/session_config.dart';
import '../entities/study_session.dart';

/// The mobile app's only window onto study sessions (contract §A3). Every
/// call that changes a session returns the whole session as the server now
/// has it.
abstract class StudySessionRepository {
  Future<Result<StudySession>> startSession(SessionConfig config);

  Future<Result<StudySession>> getSession(String sessionId);

  /// Newest first.
  Future<Result<Paginated<StudySessionSummary>>> listSessions({
    int page = 1,
    int limit = 20,
  });

  /// Records the student's choice. [timeSpentSeconds] is *added* to the
  /// question's stored total — send only the time since the last call.
  Future<Result<StudySession>> answerQuestion({
    required String sessionId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  });

  Future<Result<StudySession>> flagQuestion({
    required String sessionId,
    required String questionId,
    required bool flagged,
  });

  Future<Result<StudySession>> pauseSession(String sessionId);

  Future<Result<StudySession>> resumeSession(String sessionId);

  /// Completes the session; one that is already completed is fetched
  /// instead, so a retried completion still lands on the result.
  Future<Result<StudySession>> completeSession(String sessionId);
}
