import 'exam_question.dart';

/// What starting an exam returns: a server-assigned attempt id (every later
/// call — submit/getReview — is scoped to this id), the question set
/// already in the order the student will see them, and the **authoritative**
/// duration for this attempt.
///
/// [durationSeconds] comes from the server, not from [ExamConfig.duration]
/// — the client's requested duration is only a request; a real backend may
/// clamp, ignore, or override it (e.g. an entitlement-based limit). The
/// countdown timer is seeded from this field, never from the config the
/// student picked.
class ExamAttempt {
  const ExamAttempt({
    required this.attemptId,
    required this.questions,
    required this.durationSeconds,
  });

  final String attemptId;
  final List<ExamQuestion> questions;
  final int durationSeconds;
}
