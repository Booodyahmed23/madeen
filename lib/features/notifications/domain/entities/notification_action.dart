/// Every destination a notification is allowed to deep-link into — a closed
/// set of already-existing app routes (Study Session Setup, Exam
/// Simulation, Performance, an attempt, Plans), never a raw route string on
/// the wire. This is what keeps [NotificationActionResolver] (see
/// `../../presentation/navigation/notification_action_resolver.dart`) a
/// single, centralized, exhaustively-`switch`-checked place that decides
/// navigation — nothing else in this feature hardcodes a route path.
///
/// [none] is "no action" (the API sends `action: null`, e.g. a plain system
/// notice); it is distinct from an unrecognized wire value, which
/// [NotificationActionType.fromWire] maps to [unknown] instead of throwing,
/// so a client running behind a newer API degrades to "show details"
/// rather than crashing (contract §A9).
enum NotificationActionType {
  openStudySetup,
  openExamSetup,
  openPerformance,
  openTopicPerformance,
  openAttempt,
  openPlans,
  none,

  /// A value the client doesn't recognize (or doesn't recognize yet) —
  /// treated like [none] by the resolver.
  unknown;

  static NotificationActionType fromWire(String value) => switch (value) {
    'OPEN_STUDY_SETUP' => NotificationActionType.openStudySetup,
    'OPEN_EXAM_SETUP' => NotificationActionType.openExamSetup,
    'OPEN_PERFORMANCE' => NotificationActionType.openPerformance,
    'OPEN_TOPIC_PERFORMANCE' => NotificationActionType.openTopicPerformance,
    'OPEN_ATTEMPT' => NotificationActionType.openAttempt,
    'OPEN_PLANS' => NotificationActionType.openPlans,
    _ => NotificationActionType.unknown,
  };

  String? toWire() => switch (this) {
    NotificationActionType.openStudySetup => 'OPEN_STUDY_SETUP',
    NotificationActionType.openExamSetup => 'OPEN_EXAM_SETUP',
    NotificationActionType.openPerformance => 'OPEN_PERFORMANCE',
    NotificationActionType.openTopicPerformance => 'OPEN_TOPIC_PERFORMANCE',
    NotificationActionType.openAttempt => 'OPEN_ATTEMPT',
    NotificationActionType.openPlans => 'OPEN_PLANS',
    NotificationActionType.none || NotificationActionType.unknown => null,
  };
}

/// Where tapping a notification leads, and the record it's about.
class NotificationAction {
  const NotificationAction({
    this.type = NotificationActionType.none,
    this.targetId,
    this.attemptType,
  });

  final NotificationActionType type;
  final String? targetId;

  /// For [NotificationActionType.openAttempt]: `STUDY` or `EXAM`.
  final String? attemptType;
}
