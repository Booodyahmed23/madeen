import '../../../../core/error/result.dart';
import '../entities/question_feedback.dart';
import '../entities/question_review_item.dart';
import '../entities/session_config.dart';
import '../entities/session_result.dart';
import '../entities/study_session_bundle.dart';

/// The mobile app's only window onto Question Bank / Study Session data —
/// presentation code depends on this interface, never on a concrete data
/// source (see STUDY_SESSION_API_REQUIREMENTS.md at the repo root of
/// mobile/ for the proposed backend contract this mirrors).
abstract class StudySessionRepository {
  Future<Result<StudySessionBundle>> startSession(SessionConfig config);

  /// Immediate-feedback mode only — records the answer server-side and
  /// returns the correct answer + explanation for *this* question. Never
  /// called in "feedback at end" mode (answers there are held locally and
  /// sent all at once via [submitSession]).
  Future<Result<QuestionFeedback>> submitAnswer({
    required String sessionId,
    required String questionId,
    String? selectedChoiceId,
  });

  /// Finalizes the session and returns the authoritative [SessionResult].
  /// Called exactly once per session, in both feedback modes — `answers`
  /// is the complete question-id → selected-choice-id map (nulls allowed
  /// for unanswered questions), sent idempotently even if some were already
  /// recorded via [submitAnswer].
  Future<Result<SessionResult>> submitSession({
    required String sessionId,
    required Map<String, String?> answers,
    required Duration totalTime,
  });

  /// Full per-question review — only meaningful after [submitSession].
  Future<Result<List<QuestionReviewItem>>> getReview(String sessionId);
}
