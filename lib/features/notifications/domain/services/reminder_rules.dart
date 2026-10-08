import '../entities/notification_preferences.dart';
import '../entities/notification_type.dart';
import '../entities/reminder_repeat.dart';
import '../entities/study_reminder.dart';

/// Whether [reminder] should fire on this device under [preferences] —
/// reminders fire locally, so the app applies the reminder toggles itself
/// (contract §A9):
/// - study reminders follow "Study reminders", and daily ones also
///   "Daily study reminders";
/// - exam reminders follow "Exam reminders".
/// "Simulation reminders" has no reminder type of its own yet.
bool reminderShouldFire(
  StudyReminder reminder,
  NotificationPreferences preferences,
) {
  if (!reminder.enabled) return false;
  return switch (reminder.notificationType) {
    NotificationType.examReminder => preferences.examReminders,
    _ =>
      preferences.studyReminders &&
          (reminder.repeat != ReminderRepeat.everyDay ||
              preferences.dailyStudyReminders),
  };
}

/// The next [hour]:[minute] strictly after [from], in [from]'s time zone —
/// when a `ONE_TIME` reminder fires.
DateTime nextTimeOfDay(DateTime from, int hour, int minute) {
  final today = DateTime(from.year, from.month, from.day, hour, minute);
  return today.isAfter(from) ? today : today.add(const Duration(days: 1));
}

/// Whether an enabled `ONE_TIME` reminder has already fired: its time
/// passed since it was last saved. The app then switches it off on the
/// server (`{ enabled: false }`).
bool oneTimeReminderHasFired(StudyReminder reminder, DateTime now) {
  if (!reminder.enabled || reminder.repeat != ReminderRepeat.oneTime) {
    return false;
  }
  final savedAt = (reminder.updatedAt ?? reminder.createdAt).toLocal();
  return !now.isBefore(nextTimeOfDay(savedAt, reminder.hour, reminder.minute));
}
