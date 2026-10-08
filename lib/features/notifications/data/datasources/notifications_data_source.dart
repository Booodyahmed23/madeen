import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../models/notification_item_model.dart';
import '../models/notification_preferences_model.dart';
import '../models/study_reminder_model.dart';
import 'notifications_mock_data_source.dart';
import 'notifications_remote_data_source.dart';

/// Shape both [NotificationsRemoteDataSource] (real backend, once it
/// exists — see NOTIFICATIONS_API_REQUIREMENTS.md) and
/// [NotificationsMockDataSource] (deterministic in-memory sample data)
/// implement. NotificationsRepositoryImpl depends on this interface, not on
/// either concrete implementation — mirrors performance_data_source.dart/
/// ai_analysis_data_source.dart's own pattern exactly.
abstract class NotificationsDataSource {
  Future<List<NotificationItemModel>> getNotifications();
  Future<int> getUnreadCount();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);

  Future<NotificationPreferencesModel> getNotificationPreferences();
  Future<void> updateNotificationPreferences(
    NotificationPreferencesModel preferences,
  );

  Future<List<StudyReminderModel>> getStudyReminders();
  Future<StudyReminderModel> createStudyReminder(StudyReminderDraft draft);
  Future<StudyReminderModel> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  );
  Future<void> deleteStudyReminder(String reminderId);
  Future<StudyReminderModel> toggleStudyReminder(
    String reminderId,
    bool enabled,
  );
}

/// The single switch between real and sample Notifications data. See
/// AppConfig.isNotificationsApiAvailable and NOTIFICATIONS_API_
/// REQUIREMENTS.md — flipping the `NOTIFICATIONS_API_AVAILABLE` dart-define
/// is the only change needed once the backend ships these endpoints. Not
/// `autoDispose`: the mock datasource holds mutable in-memory state (read/
/// unread, reminders, preferences) that must survive across screens for the
/// whole app session — see NotificationsMockDataSource's doc comment.
final notificationsDataSourceProvider = Provider<NotificationsDataSource>((
  ref,
) {
  if (AppConfig.isNotificationsApiAvailable) {
    return NotificationsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return NotificationsMockDataSource();
});
