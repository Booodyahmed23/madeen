import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/study_reminder.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_data_source.dart';
import '../models/notification_preferences_model.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._dataSource);

  final NotificationsDataSource _dataSource;

  @override
  Future<Result<List<NotificationItem>>> getNotifications() => _guard(
    () async => (await _dataSource.getNotifications())
        .map((m) => m.toEntity())
        .toList(),
  );

  @override
  Future<Result<int>> getUnreadCount() =>
      _guard(() => _dataSource.getUnreadCount());

  @override
  Future<Result<void>> markAsRead(String notificationId) =>
      _guard(() => _dataSource.markAsRead(notificationId));

  @override
  Future<Result<void>> markAllAsRead() =>
      _guard(() => _dataSource.markAllAsRead());

  @override
  Future<Result<void>> deleteNotification(String notificationId) =>
      _guard(() => _dataSource.deleteNotification(notificationId));

  @override
  Future<Result<NotificationPreferences>> getNotificationPreferences() =>
      _guard(
        () async => (await _dataSource.getNotificationPreferences()).toEntity(),
      );

  @override
  Future<Result<void>> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) => _guard(
    () => _dataSource.updateNotificationPreferences(
      NotificationPreferencesModel.fromEntity(preferences),
    ),
  );

  @override
  Future<Result<List<StudyReminder>>> getStudyReminders() => _guard(
    () async => (await _dataSource.getStudyReminders())
        .map((m) => m.toEntity())
        .toList(),
  );

  @override
  Future<Result<StudyReminder>> createStudyReminder(StudyReminderDraft draft) =>
      _guard(
        () async => (await _dataSource.createStudyReminder(draft)).toEntity(),
      );

  @override
  Future<Result<StudyReminder>> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  ) => _guard(
    () async =>
        (await _dataSource.updateStudyReminder(reminderId, draft)).toEntity(),
  );

  @override
  Future<Result<void>> deleteStudyReminder(String reminderId) =>
      _guard(() => _dataSource.deleteStudyReminder(reminderId));

  @override
  Future<Result<StudyReminder>> toggleStudyReminder(
    String reminderId,
    bool enabled,
  ) => _guard(
    () async =>
        (await _dataSource.toggleStudyReminder(reminderId, enabled)).toEntity(),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (error) {
      // Malformed/unexpected response shape, or a mock-data inconsistency
      // (e.g. unknown notificationId/reminderId) — never let a raw
      // exception reach the UI, same rule as every other repository.
      return const Result.failure(UnknownFailure());
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepositoryImpl(
    ref.watch(notificationsDataSourceProvider),
  );
});
