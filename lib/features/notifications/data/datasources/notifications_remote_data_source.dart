import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../models/study_reminder_model.dart';
import 'notifications_data_source.dart';

/// `/notifications/*` and `/study-reminders/*` (contract §A9). Sends only
/// the documented fields — the API rejects unknown ones with `400`.
class NotificationsRemoteDataSource implements NotificationsDataSource {
  NotificationsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static Json _json(dynamic data) => data as Json;

  @override
  Future<Json> getNotifications({
    required int page,
    required int limit,
    required List<String> types,
    required bool unreadOnly,
  }) {
    return _apiClient.get(
      '/notifications',
      queryParameters: {
        ...pageQuery(page: page, limit: limit),
        if (unreadOnly) 'unreadOnly': true,
        // A list repeats the key: `type=A&type=B`.
        if (types.isNotEmpty) 'type': types,
      },
      parse: _json,
    );
  }

  @override
  Future<Json> getNotification(String notificationId) =>
      _apiClient.get('/notifications/$notificationId', parse: _json);

  @override
  Future<int> getUnreadCount() {
    return _apiClient.get(
      '/notifications/unread-count',
      parse: (data) => ((data as Json)['count'] as num).toInt(),
    );
  }

  @override
  Future<Json> markAsRead(String notificationId) =>
      _apiClient.patch('/notifications/$notificationId/read', parse: _json);

  @override
  Future<int> markAllAsRead() {
    return _apiClient.post(
      '/notifications/read-all',
      parse: (data) => ((data as Json)['updated'] as num).toInt(),
    );
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _apiClient.delete('/notifications/$notificationId', parse: (_) {});
  }

  @override
  Future<Json> getNotificationPreferences() =>
      _apiClient.get('/notifications/preferences', parse: _json);

  @override
  Future<Json> updateNotificationPreferences(Map<String, bool> changes) {
    return _apiClient.patch(
      '/notifications/preferences',
      data: changes,
      parse: _json,
    );
  }

  @override
  Future<List<StudyReminderModel>> getStudyReminders() {
    return _apiClient.get(
      '/study-reminders',
      parse: (data) => [
        for (final json in data as List)
          StudyReminderModel.fromJson(json as Json),
      ],
    );
  }

  @override
  Future<StudyReminderModel> createStudyReminder(StudyReminderDraft draft) {
    return _apiClient.post(
      '/study-reminders',
      data: studyReminderDraftToJson(draft),
      parse: (data) => StudyReminderModel.fromJson(data as Json),
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
      parse: (data) => StudyReminderModel.fromJson(data as Json),
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
      parse: (data) => StudyReminderModel.fromJson(data as Json),
    );
  }
}
