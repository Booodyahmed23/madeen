import '../../../../core/network/api_client.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../models/notification_item_model.dart';
import '../models/notification_preferences_model.dart';
import '../models/study_reminder_model.dart';
import 'notifications_data_source.dart';

/// Talks to the Notifications endpoints proposed in NOTIFICATIONS_API_
/// REQUIREMENTS.md (mobile/ root).
///
/// ⚠️ NOT YET INTEGRATION-TESTED AGAINST A REAL BACKEND — as of Phase 8,
/// backend/ has no Notifications module (verified by inspection: only
/// `identity` and `notification` — the transactional email/SMS dispatch
/// module, a different concern, see docs/ARCHITECTURE.md §3's module table
/// — exist under backend/src/modules/). This class exists so the mobile
/// app's abstraction is ready the day the real endpoints ship; until then
/// it is wired up but not selected by default — see
/// AppConfig.isNotificationsApiAvailable and notifications_data_source.dart.
class NotificationsRemoteDataSource implements NotificationsDataSource {
  NotificationsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<NotificationItemModel>> getNotifications() {
    return _apiClient.get(
      '/notifications',
      parse: (data) => (data as List)
          .map(
            (json) =>
                NotificationItemModel.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  Future<int> getUnreadCount() {
    return _apiClient.get(
      '/notifications/unread-count',
      parse: (data) => ((data as Map<String, dynamic>)['count'] as num).toInt(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _apiClient.patch(
      '/notifications/$notificationId/read',
      data: const {'isRead': true},
      parse: (_) {},
    );
  }

  @override
  Future<void> markAllAsRead() {
    return _apiClient.post('/notifications/read-all', parse: (_) {});
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _apiClient.delete('/notifications/$notificationId', parse: (_) {});
  }

  @override
  Future<NotificationPreferencesModel> getNotificationPreferences() {
    return _apiClient.get(
      '/notifications/preferences',
      parse: (data) =>
          NotificationPreferencesModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferencesModel preferences,
  ) {
    return _apiClient.patch(
      '/notifications/preferences',
      data: preferences.toJson(),
      parse: (_) {},
    );
  }

  @override
  Future<List<StudyReminderModel>> getStudyReminders() {
    return _apiClient.get(
      '/study-reminders',
      parse: (data) => (data as List)
          .map(
            (json) => StudyReminderModel.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  Future<StudyReminderModel> createStudyReminder(StudyReminderDraft draft) {
    return _apiClient.post(
      '/study-reminders',
      data: studyReminderDraftToJson(draft),
      parse: (data) =>
          StudyReminderModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<StudyReminderModel> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  ) {
    return _apiClient.patch(
      '/study-reminders/$reminderId',
      data: studyReminderDraftToJson(draft),
      parse: (data) =>
          StudyReminderModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> deleteStudyReminder(String reminderId) {
    return _apiClient.delete('/study-reminders/$reminderId', parse: (_) {});
  }

  @override
  Future<StudyReminderModel> toggleStudyReminder(
    String reminderId,
    bool enabled,
  ) {
    return _apiClient.patch(
      '/study-reminders/$reminderId',
      data: {'enabled': enabled},
      parse: (data) =>
          StudyReminderModel.fromJson(data as Map<String, dynamic>),
    );
  }
}
