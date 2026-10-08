import '../entities/notification_preferences.dart';
import '../entities/study_reminder.dart';

/// Local (on-device) notification scheduling, decoupled from any specific
/// plugin — the UI and `NotificationsRepository` depend on this interface
/// only, never on a notification package directly.
///
/// The app uses `LocalNotificationScheduler` (real device notifications);
/// `MockNotificationScheduler` records calls for tests. Every
/// implementation applies [applyPreferences] itself, so callers just
/// schedule what the server has.
abstract class NotificationScheduler {
  /// The reminder toggles to honour from now on — reschedules everything
  /// already scheduled under them (see reminderShouldFire).
  Future<void> applyPreferences(NotificationPreferences preferences);

  /// Replaces everything scheduled with [reminders] — after sign-in, each
  /// sync and on app start.
  Future<void> scheduleAll(List<StudyReminder> reminders) async {
    await cancelAll();
    for (final reminder in reminders) {
      await schedule(reminder);
    }
  }

  /// Schedules (or, if [reminder.id] was already scheduled, replaces) local
  /// notifications for every day in [StudyReminder.resolvedDays] at
  /// [StudyReminder.hour]:[StudyReminder.minute]. A no-op for a reminder
  /// whose [StudyReminder.enabled] is `false` or whose [StudyReminder.
  /// resolvedDays] is empty (a disabled or day-less reminder has nothing to
  /// schedule) — callers don't need to check either condition themselves.
  Future<void> schedule(StudyReminder reminder);

  /// Cancels whatever [schedule] previously scheduled for this reminder id,
  /// if anything. A no-op if nothing was scheduled for it.
  Future<void> cancel(String reminderId);

  /// Convenience for "the draft changed" — implementations may do this as
  /// cancel-then-schedule, or something smarter; callers should not assume
  /// either.
  Future<void> update(StudyReminder reminder) async {
    await cancel(reminder.id);
    await schedule(reminder);
  }

  /// Cancels every reminder this scheduler currently has scheduled — used
  /// when notifications are globally disabled (see
  /// NotificationPreferences.studyReminders flipping to `false`).
  Future<void> cancelAll();
}
