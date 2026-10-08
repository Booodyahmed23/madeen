import 'tutor_message_role.dart';

/// One message in an AI Tutor conversation — always sourced from
/// [TutorRepository] (never constructed ad hoc by the UI), the same
/// authoritative-data rule every other domain entity in this app follows.
class TutorMessage {
  const TutorMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final TutorMessageRole role;
  final String content;
  final DateTime timestamp;

  bool get isFromUser => role == TutorMessageRole.user;
}
