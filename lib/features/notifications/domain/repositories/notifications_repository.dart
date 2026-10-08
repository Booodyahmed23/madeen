import '../../../../core/error/result.dart';
import '../../../../core/network/paginated.dart';
import '../entities/notification_item.dart';
import '../entities/notification_preferences.dart';
import '../entities/study_reminder.dart';
import '../entities/study_reminder_draft.dart';

/// Notification Center, preferences and study reminders (contract §A9).
abstract class NotificationsRepository {
  /// One page, newest first, filtered on the server by [filter].
  Future<Result<Paginated<NotificationItem>>> getNotifications({
    int page = 1,
    int limit = 20,
    NotificationListFilter filter = NotificationListFilter.all,
  });

  /// One notification — for details opened from a deep link or push tap,
  /// when it isn't in the loaded list.
  Future<Result<NotificationItem>> getNotification(String notificationId);

  Future<Result<int>> getUnreadCount();

  Future<Result<NotificationItem>> markAsRead(String notificationId);

  Future<Result<int>> markAllAsRead();

  Future<Result<void>> deleteNotification(String notificationId);

  Future<Result<NotificationPreferences>> getNotificationPreferences();

  /// Sends only what changed from [previous]; returns the saved set.
  Future<Result<NotificationPreferences>> updateNotificationPreferences(
    NotificationPreferences updated, {
    required NotificationPreferences previous,
  });

  Future<Result<List<StudyReminder>>> getStudyReminders();

  /// `400 REMINDER_LIMIT_REACHED` (max 20) / `INVALID_CUSTOM_DAYS` come
  /// back as failures with their code.
  Future<Result<StudyReminder>> createStudyReminder(StudyReminderDraft draft);

  Future<Result<StudyReminder>> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  );

  Future<Result<void>> deleteStudyReminder(String reminderId);

  Future<Result<StudyReminder>> toggleStudyReminder(
    String reminderId,
    bool enabled,
  );
}
