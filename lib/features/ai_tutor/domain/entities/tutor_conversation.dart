import 'tutor_message.dart';

/// One AI Tutor conversation — kept entirely client-side for this phase
/// (no persistence, no history list across app restarts; see this
/// feature's README/AI_TUTOR_API_REQUIREMENTS.md for why). [id] exists now
/// so a future real backend can key a persisted conversation by it without
/// a shape change here.
class TutorConversation {
  const TutorConversation({
    required this.id,
    required this.messages,
    required this.createdAt,
  });

  final String id;
  final List<TutorMessage> messages;
  final DateTime createdAt;

  bool get isEmpty => messages.isEmpty;

  TutorConversation withMessage(TutorMessage message) => TutorConversation(
    id: id,
    messages: [...messages, message],
    createdAt: createdAt,
  );
}
