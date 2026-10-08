/// What a notification is about. Drives the icon shown in the list, the
/// default entry in [NotificationPreferences] it's gated by, and — via
/// [NotificationListFilter] — which category tab surfaces it. Adding a
/// certification-specific type later (e.g. a Course-progress notification)
/// is a new enum value here, not a redesign.
enum NotificationType {
  studyReminder,
  examReminder,
  performanceUpdate,
  achievement,
  system,

  /// A type this build doesn't know (the API may add more) — shown as a
  /// plain notice, never an error (contract §A9).
  unknown;

  static NotificationType fromWire(String value) {
    switch (value) {
      case 'STUDY_REMINDER':
        return NotificationType.studyReminder;
      case 'EXAM_REMINDER':
        return NotificationType.examReminder;
      case 'PERFORMANCE_UPDATE':
        return NotificationType.performanceUpdate;
      case 'ACHIEVEMENT':
        return NotificationType.achievement;
      case 'SYSTEM':
        return NotificationType.system;
      default:
        return NotificationType.unknown;
    }
  }

  String toWire() => switch (this) {
    NotificationType.studyReminder => 'STUDY_REMINDER',
    NotificationType.examReminder => 'EXAM_REMINDER',
    NotificationType.performanceUpdate => 'PERFORMANCE_UPDATE',
    NotificationType.achievement => 'ACHIEVEMENT',
    NotificationType.system => 'SYSTEM',
    NotificationType.unknown => 'UNKNOWN',
  };
}

/// How urgently a notification should be surfaced — communicated via icon
/// emphasis/label, never color alone (see the phase brief's accessibility
/// rule, mirrored from Performance/AI Analysis's own strong/needs-practice
/// badges).
enum NotificationPriority {
  low,
  normal,
  high;

  static NotificationPriority fromWire(String value) {
    switch (value) {
      case 'LOW':
        return NotificationPriority.low;
      case 'NORMAL':
        return NotificationPriority.normal;
      case 'HIGH':
        return NotificationPriority.high;
      default:
        throw FormatException('Unknown notification priority: $value');
    }
  }

  String toWire() => switch (this) {
    NotificationPriority.low => 'LOW',
    NotificationPriority.normal => 'NORMAL',
    NotificationPriority.high => 'HIGH',
  };
}
