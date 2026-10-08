import '../entities/study_reminder.dart';

/// Local (on-device) notification scheduling, decoupled from any specific
/// plugin — the UI and `NotificationsRepository` depend on this interface
/// only, never on a notification package directly, so adopting a real
/// scheduler later (e.g. `flutter_local_notifications`) touches exactly one
/// new implementation class, never a screen or the repository.
///
/// **No implementation of this interface schedules a real OS-level
/// notification in this phase** — see `../../data/services/
/// mock_notification_scheduler.dart`'s doc comment and NOTIFICATIONS_API_
/// REQUIREMENTS.md's "Local notification status" section. Do not present
/// scheduling through this interface as a working device notification to a
/// user or reviewer.
abstract class NotificationScheduler {
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
