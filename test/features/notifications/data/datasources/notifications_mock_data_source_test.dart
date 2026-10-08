import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/datasources/notifications_mock_data_source.dart';
import 'package:mobile/features/notifications/data/models/notification_preferences_model.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';

void main() {
  group('NotificationsMockDataSource notifications', () {
    test(
      'getNotifications returns the seven seeded, most-recent-first',
      () async {
        final source = NotificationsMockDataSource();
        final notifications = await source.getNotifications();

        expect(notifications, hasLength(7));
        for (var i = 0; i < notifications.length - 1; i++) {
          expect(
            notifications[i].createdAt.isAfter(notifications[i + 1].createdAt),
            isTrue,
          );
        }
      },
    );

    test('getUnreadCount matches the number of unread seeded items', () async {
      final source = NotificationsMockDataSource();
      final notifications = await source.getNotifications();
      final expected = notifications.where((n) => !n.isRead).length;

      expect(await source.getUnreadCount(), expected);
    });

    test(
      'markAsRead persists across subsequent reads on the same instance',
      () async {
        final source = NotificationsMockDataSource();
        await source.markAsRead('notif-1');

        final notifications = await source.getNotifications();
        final marked = notifications.firstWhere((n) => n.id == 'notif-1');
        expect(marked.isRead, isTrue);
      },
    );

    test('markAsRead throws for an unknown id', () async {
      final source = NotificationsMockDataSource();
      expect(() => source.markAsRead('missing'), throwsStateError);
    });

    test('markAllAsRead marks every notification read', () async {
      final source = NotificationsMockDataSource();
      await source.markAllAsRead();

      final notifications = await source.getNotifications();
      expect(notifications.every((n) => n.isRead), isTrue);
      expect(await source.getUnreadCount(), 0);
    });

    test('deleteNotification removes it from subsequent reads', () async {
      final source = NotificationsMockDataSource();
      await source.deleteNotification('notif-1');

      final notifications = await source.getNotifications();
      expect(notifications.any((n) => n.id == 'notif-1'), isFalse);
    });

    test('deleteNotification throws for an unknown id', () async {
      final source = NotificationsMockDataSource();
      expect(() => source.deleteNotification('missing'), throwsStateError);
    });
  });

  group('NotificationsMockDataSource preferences', () {
    test('getNotificationPreferences defaults every toggle to true', () async {
      final source = NotificationsMockDataSource();
      final preferences = await source.getNotificationPreferences();

      expect(preferences.studyReminders, isTrue);
      expect(preferences.systemNotifications, isTrue);
    });

    test(
      'updateNotificationPreferences persists across subsequent reads',
      () async {
        final source = NotificationsMockDataSource();
        final current = await source.getNotificationPreferences();
        final updatedEntity = current.toEntity().copyWith(
          studyReminders: false,
        );
        await source.updateNotificationPreferences(
          NotificationPreferencesModel.fromEntity(updatedEntity),
        );

        final updated = await source.getNotificationPreferences();
        expect(updated.studyReminders, isFalse);
      },
    );
  });

  group('NotificationsMockDataSource study reminders', () {
    test('getStudyReminders returns the three seeded reminders', () async {
      final source = NotificationsMockDataSource();
      final reminders = await source.getStudyReminders();
      expect(reminders, hasLength(3));
    });

    test('createStudyReminder assigns a new id and appends it', () async {
      final source = NotificationsMockDataSource();
      const draft = StudyReminderDraft(
        title: 'New reminder',
        enabled: true,
        hour: 9,
        minute: 0,
        repeat: ReminderRepeat.everyDay,
      );

      final created = await source.createStudyReminder(draft);
      expect(created.title, 'New reminder');

      final reminders = await source.getStudyReminders();
      expect(reminders, hasLength(4));
      expect(reminders.any((r) => r.id == created.id), isTrue);
    });

    test(
      'updateStudyReminder replaces fields but keeps id/createdAt',
      () async {
        final source = NotificationsMockDataSource();
        const draft = StudyReminderDraft(
          title: 'Updated title',
          enabled: false,
          hour: 6,
          minute: 15,
          repeat: ReminderRepeat.weekends,
        );

        final updated = await source.updateStudyReminder('reminder-1', draft);
        expect(updated.id, 'reminder-1');
        expect(updated.title, 'Updated title');
        expect(updated.enabled, isFalse);
      },
    );

    test('updateStudyReminder throws for an unknown id', () async {
      final source = NotificationsMockDataSource();
      const draft = StudyReminderDraft(
        title: 'x',
        enabled: true,
        hour: 8,
        minute: 0,
        repeat: ReminderRepeat.everyDay,
      );
      expect(
        () => source.updateStudyReminder('missing', draft),
        throwsStateError,
      );
    });

    test('deleteStudyReminder removes it from subsequent reads', () async {
      final source = NotificationsMockDataSource();
      await source.deleteStudyReminder('reminder-1');

      final reminders = await source.getStudyReminders();
      expect(reminders.any((r) => r.id == 'reminder-1'), isFalse);
    });

    test('toggleStudyReminder flips only enabled', () async {
      final source = NotificationsMockDataSource();
      final toggled = await source.toggleStudyReminder('reminder-3', true);
      expect(toggled.id, 'reminder-3');
      expect(toggled.enabled, isTrue);
    });
  });
}
