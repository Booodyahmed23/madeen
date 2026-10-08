import '../../../../core/error/result.dart';
import '../entities/notification_item.dart';
import '../entities/notification_preferences.dart';
import '../entities/study_reminder.dart';
import '../entities/study_reminder_draft.dart';

/// The mobile app's only window onto Notifications & Study Reminders —
/// presentation code depends on this interface, never on a concrete data
/// source (see NOTIFICATIONS_API_REQUIREMENTS.md at the repo root of
/// mobile/ for the proposed backend contract this mirrors). Every method
/// returns `Result` — same error-handling seam as every other repository in
/// this app — so a mock-mode failure (there basically never is one) and a
/// real backend failure surface identically to the UI.
abstract class NotificationsRepository {
  Future<Result<List<NotificationItem>>> getNotifications();

  /// Cheap enough to poll independently of [getNotifications] (e.g. to
  /// refresh Home's badge without re-fetching the whole list) — see
  /// `unreadNotificationCountProvider`.
  Future<Result<int>> getUnreadCount();

  Future<Result<void>> markAsRead(String notificationId);
  Future<Result<void>> markAllAsRead();
  Future<Result<void>> deleteNotification(String notificationId);

  Future<Result<NotificationPreferences>> getNotificationPreferences();
  Future<Result<void>> updateNotificationPreferences(
    NotificationPreferences preferences,
  );

  Future<Result<List<StudyReminder>>> getStudyReminders();
  Future<Result<StudyReminder>> createStudyReminder(StudyReminderDraft draft);
  Future<Result<StudyReminder>> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  );
  Future<Result<void>> deleteStudyReminder(String reminderId);

  /// A narrower alternative to [updateStudyReminder] for the one-tap
  /// enable/disable switch on the Study Reminders list — going through the
  /// full draft there would force the list screen to reconstruct a
  /// [StudyReminderDraft] from a [StudyReminder] just to flip one field.
  Future<Result<StudyReminder>> toggleStudyReminder(
    String reminderId,
    bool enabled,
  );
}
