import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../models/study_reminder_model.dart';
import 'notifications_mock_data_source.dart';
import 'notifications_remote_data_source.dart';

typedef Json = Map<String, dynamic>;

/// `/notifications/*` and `/study-reminders/*` (contract §A9). Notification
/// calls return the API's raw JSON (a `{ data, meta }` page, a
/// Notification, the seven preferences), produced identically by both
/// implementations so one parser serves both.
abstract class NotificationsDataSource {
  /// Newest first. [types] repeat as `type=…`; empty means every type.
  Future<Json> getNotifications({
    required int page,
    required int limit,
    required List<String> types,
    required bool unreadOnly,
  });

  Future<Json> getNotification(String notificationId);

  Future<int> getUnreadCount();

  /// No body; returns the notification (read again keeps the first readAt).
  Future<Json> markAsRead(String notificationId);

  /// Returns how many were updated.
  Future<int> markAllAsRead();

  Future<void> deleteNotification(String notificationId);

  Future<Json> getNotificationPreferences();

  /// Sends only [changes]; returns all seven preferences.
  Future<Json> updateNotificationPreferences(Map<String, bool> changes);

  /// At most 20 — a plain array.
  Future<List<StudyReminderModel>> getStudyReminders();

  Future<StudyReminderModel> createStudyReminder(StudyReminderDraft draft);

  Future<StudyReminderModel> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  );

  Future<void> deleteStudyReminder(String reminderId);

  /// The on/off switch sends `{ enabled }` alone.
  Future<StudyReminderModel> toggleStudyReminder(
    String reminderId,
    bool enabled,
  );
}

/// The single switch between the real API and sample data — the
/// `NOTIFICATIONS_API_AVAILABLE` dart-define (see AppConfig).
final notificationsDataSourceProvider = Provider<NotificationsDataSource>((
  ref,
) {
  if (AppConfig.isNotificationsApiAvailable) {
    return NotificationsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return NotificationsMockDataSource();
});
