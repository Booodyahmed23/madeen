import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder.dart';
import '../../domain/services/reminder_rules.dart';
import '../../domain/services/notification_scheduler.dart';

/// **Does not schedule a real OS-level notification** — records which
/// reminder ids would be scheduled, in memory, applying the same rules as
/// LocalNotificationScheduler. For tests.
class MockNotificationScheduler extends NotificationScheduler {
  final Set<String> _scheduledReminderIds = {};
  final Map<String, StudyReminder> _reminders = {};
  NotificationPreferences _preferences = const NotificationPreferences();

  @override
  Future<void> applyPreferences(NotificationPreferences preferences) async {
    _preferences = preferences;
    final known = _reminders.values.toList();
    _scheduledReminderIds.clear();
    for (final reminder in known) {
      await schedule(reminder);
    }
  }

  /// Exposed for tests/debugging only — not part of [NotificationScheduler]
  /// itself, since "what's currently scheduled" isn't a capability a real
  /// OS-level scheduler API can answer synchronously.
  Set<String> get scheduledReminderIds =>
      Set.unmodifiable(_scheduledReminderIds);

  @override
  Future<void> schedule(StudyReminder reminder) async {
    _reminders[reminder.id] = reminder;
    final oneTime = reminder.repeat == ReminderRepeat.oneTime;
    if (!reminderShouldFire(reminder, _preferences) ||
        (!oneTime && reminder.resolvedDays.isEmpty)) {
      _scheduledReminderIds.remove(reminder.id);
      return;
    }
    _scheduledReminderIds.add(reminder.id);
  }

  @override
  Future<void> cancel(String reminderId) async {
    _reminders.remove(reminderId);
    _scheduledReminderIds.remove(reminderId);
  }

  @override
  Future<void> update(StudyReminder reminder) async {
    await cancel(reminder.id);
    await schedule(reminder);
  }

  @override
  Future<void> cancelAll() async {
    _reminders.clear();
    _scheduledReminderIds.clear();
  }
}
