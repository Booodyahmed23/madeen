import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/result.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../features/notifications/data/services/local_notification_scheduler.dart';
import '../features/notifications/domain/entities/study_reminder.dart';
import '../features/notifications/domain/services/reminder_rules.dart';

/// The clock reminder sync reads — a provider so tests can pin it.
final reminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Keeps the device's scheduled study reminders in step with the server
/// (contract §A9: reminders fire on the device, the API only stores them).
/// On sign-in — including a session restored at app start — it applies the
/// reminder preferences, switches off `ONE_TIME` reminders that already
/// fired, and reschedules everything; on sign-out it clears them.
///
/// Kept alive for the app's lifetime by app/app.dart.
final reminderSyncProvider = Provider<void>((ref) {
  ref.listen(
    authNotifierProvider.select(
      (state) => state is AuthAuthenticated ? state.user.id : null,
    ),
    (previous, userId) {
      if (userId != null) {
        syncReminders(ref);
      } else if (previous != null) {
        ref.read(notificationSchedulerProvider).cancelAll();
      }
    },
    fireImmediately: true,
  );
});

/// One sync. Best-effort: when it fails (offline, server error) the
/// reminders scheduled last time stay, and the app is never disturbed.
@visibleForTesting
Future<void> syncReminders(Ref ref) async {
  try {
    final repository = ref.read(notificationsRepositoryProvider);
    final scheduler = ref.read(notificationSchedulerProvider);

    if (await repository.getNotificationPreferences() case Success(
      :final value,
    )) {
      await scheduler.applyPreferences(value);
    }
    final result = await repository.getStudyReminders();
    if (result is! Success<List<StudyReminder>>) return;

    final now = ref.read(reminderClockProvider)();
    final reminders = <StudyReminder>[];
    for (final reminder in result.value) {
      if (oneTimeReminderHasFired(reminder, now)) {
        final off = await repository.toggleStudyReminder(reminder.id, false);
        reminders.add(off is Success<StudyReminder> ? off.value : reminder);
      } else {
        reminders.add(reminder);
      }
    }
    await scheduler.scheduleAll(reminders);
  } catch (error) {
    debugPrint('Reminder sync failed: $error');
  }
}
