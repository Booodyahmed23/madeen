/// Who sent a [TutorMessage] — mirrors every other wire-mapped enum in
/// this app (e.g. `NotificationType`, `AttemptType`): a small, closed set
/// with `toWire`/`fromWire` so the data layer has a stable string to
/// (eventually) exchange with a real backend, even though today's
/// `MockAiProvider` never serializes one.
enum TutorMessageRole {
  user,
  assistant;

  static TutorMessageRole fromWire(String value) {
    switch (value) {
      case 'USER':
        return TutorMessageRole.user;
      case 'ASSISTANT':
        return TutorMessageRole.assistant;
      default:
        throw FormatException('Unknown tutor message role: $value');
    }
  }

  String toWire() => switch (this) {
    TutorMessageRole.user => 'USER',
    TutorMessageRole.assistant => 'ASSISTANT',
  };
}
