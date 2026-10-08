import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/study_reminder.dart';
import '../../domain/services/notification_scheduler.dart';

/// **Does not schedule a real OS-level notification.** This records which
/// reminder ids are "scheduled" purely in memory so the Study Reminders UI
/// has something truthful to reflect (and so tests can assert scheduling
/// was *attempted* for the right ids) — it never touches
/// `flutter_local_notifications` or any platform notification API. See
/// NOTIFICATIONS_API_REQUIREMENTS.md's "Local notification status": adding
/// a real plugin-backed implementation of [NotificationScheduler] is future
/// work, deliberately out of scope for this phase (no heavy notification
/// package is added here — see that document for why).
class MockNotificationScheduler implements NotificationScheduler {
  final Set<String> _scheduledReminderIds = {};

  /// Exposed for tests/debugging only — not part of [NotificationScheduler]
  /// itself, since "what's currently scheduled" isn't a capability a real
  /// OS-level scheduler API can answer synchronously.
  Set<String> get scheduledReminderIds =>
      Set.unmodifiable(_scheduledReminderIds);

  @override
  Future<void> schedule(StudyReminder reminder) async {
    if (!reminder.enabled || reminder.resolvedDays.isEmpty) {
      _scheduledReminderIds.remove(reminder.id);
      return;
    }
    _scheduledReminderIds.add(reminder.id);
  }

  @override
  Future<void> cancel(String reminderId) async {
    _scheduledReminderIds.remove(reminderId);
  }

  @override
  Future<void> update(StudyReminder reminder) async {
    await cancel(reminder.id);
    await schedule(reminder);
  }

  @override
  Future<void> cancelAll() async {
    _scheduledReminderIds.clear();
  }
}

/// Not `autoDispose`: a scheduler needs to remember what it scheduled for
/// as long as the app runs, same reasoning as
/// `notificationsDataSourceProvider`.
final notificationSchedulerProvider = Provider<MockNotificationScheduler>((
  ref,
) {
  return MockNotificationScheduler();
});
