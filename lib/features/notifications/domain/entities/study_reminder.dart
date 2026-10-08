import 'notification_type.dart';
import 'reminder_repeat.dart';
import 'weekday.dart';

/// A student-configured local reminder — scheduling is delegated to
/// `NotificationScheduler` (see `../services/notification_scheduler.dart`);
/// this entity is the persisted record `NotificationsRepository` reads/
/// writes, deliberately Flutter-free (time is `hour`/`minute` ints, not
/// `TimeOfDay`) to match every other domain entity in this app.
class StudyReminder {
  const StudyReminder({
    required this.id,
    required this.title,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.repeat,
    this.customDays = const {},
    this.notificationType = NotificationType.studyReminder,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool enabled;

  /// 0–23.
  final int hour;

  /// 0–59.
  final int minute;

  final ReminderRepeat repeat;

  /// Only meaningful (and only ever non-empty) when [repeat] is
  /// [ReminderRepeat.custom] — see [resolvedDays].
  final Set<Weekday> customDays;

  /// Almost always [NotificationType.studyReminder]; a reminder can instead
  /// be typed as [NotificationType.examReminder] (see Study Reminders'
  /// "Pre-Exam Revision" mock entry) so it respects that category's own
  /// [NotificationPreferences] toggle rather than the study one.
  final NotificationType notificationType;

  final DateTime createdAt;

  /// The actual days this reminder fires on, regardless of which preset
  /// produced them — the single source of truth [NotificationScheduler]
  /// and the reminders list both read, so "Weekdays" and a custom
  /// Mon–Fri selection behave identically at schedule time.
  Set<Weekday> get resolvedDays => switch (repeat) {
    ReminderRepeat.everyDay => Weekday.values.toSet(),
    ReminderRepeat.weekdays => Weekday.weekdays,
    ReminderRepeat.weekends => Weekday.weekends,
    ReminderRepeat.custom => customDays,
    ReminderRepeat.oneTime => const {},
  };

  StudyReminder copyWith({bool? enabled}) {
    return StudyReminder(
      id: id,
      title: title,
      enabled: enabled ?? this.enabled,
      hour: hour,
      minute: minute,
      repeat: repeat,
      customDays: customDays,
      notificationType: notificationType,
      createdAt: createdAt,
    );
  }
}
