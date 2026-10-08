import 'question.dart';

/// What starting a session returns: a server-assigned session id (every
/// later call — submitAnswer/submitSession/getReview — is scoped to this
/// id) plus the question set, already in the order the student will see
/// them (random order, if selected, is resolved once here — the client
/// never re-shuffles).
class StudySessionBundle {
  const StudySessionBundle({required this.sessionId, required this.questions});

  final String sessionId;
  final List<Question> questions;
}
