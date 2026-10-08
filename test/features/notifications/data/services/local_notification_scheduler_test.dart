import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/services/local_notification_scheduler.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/weekday.dart';

class _FakeClient implements LocalNotificationsClient {
  bool permitted = true;
  int permissionRequests = 0;
  final scheduled = <int, ({DateTime at, bool weekly, String title})>{};

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permitted;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required bool weekly,
    required String title,
    required String body,
  }) async => scheduled[id] = (at: at, weekly: weekly, title: title);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> cancelAll() async => scheduled.clear();
}

StudyReminder _reminder(
  String id, {
  ReminderRepeat repeat = ReminderRepeat.custom,
  Set<Weekday> days = const {Weekday.monday, Weekday.wednesday},
  bool enabled = true,
}) => StudyReminder(
  id: id,
  title: 'Reminder $id',
  enabled: enabled,
  hour: 7,
  minute: 30,
  repeat: repeat,
  customDays: days,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  late _FakeClient client;
  late LocalNotificationScheduler scheduler;
  // Thursday 8 Oct 2026, 09:00.
  final now = DateTime(2026, 10, 8, 9);

  setUp(() {
    client = _FakeClient();
    scheduler = LocalNotificationScheduler(
      client,
      bodyFor: (_) => 'Study time',
      clock: () => now,
    );
  });

  test(
    'one weekly notification per repeat day, at its next occurrence',
    () async {
      await scheduler.schedule(_reminder('r1'));

      final times = client.scheduled.values.map((s) => s.at).toList()..sort();
      expect(times, [
        DateTime(2026, 10, 12, 7, 30),
        DateTime(2026, 10, 14, 7, 30),
      ]);
      expect(client.scheduled.values.every((s) => s.weekly), isTrue);
    },
  );

  test('a one-time reminder is one notification, not repeating', () async {
    await scheduler.schedule(_reminder('r1', repeat: ReminderRepeat.oneTime));

    final only = client.scheduled.values.single;
    expect(only.weekly, isFalse);
    expect(only.at, DateTime(2026, 10, 9, 7, 30));
  });

  test(
    'a disabled reminder, or a denied permission, schedules nothing',
    () async {
      await scheduler.schedule(_reminder('r1', enabled: false));
      expect(client.scheduled, isEmpty);
      expect(client.permissionRequests, 0, reason: 'no prompt without need');

      client.permitted = false;
      await scheduler.schedule(_reminder('r2'));
      expect(client.scheduled, isEmpty);
    },
  );

  test('cancel removes only that reminder', () async {
    await scheduler.schedule(_reminder('r1'));
    await scheduler.schedule(_reminder('r2', days: {Weekday.friday}));

    await scheduler.cancel('r1');

    expect(client.scheduled.values.single.title, 'Reminder r2');
  });

  test('turning a preference off unschedules; on schedules again', () async {
    await scheduler.schedule(_reminder('r1'));

    await scheduler.applyPreferences(
      const NotificationPreferences(studyReminders: false),
    );
    expect(client.scheduled, isEmpty);

    await scheduler.applyPreferences(const NotificationPreferences());
    expect(client.scheduled, hasLength(2));
  });

  test('scheduleAll replaces everything with the server list', () async {
    await scheduler.schedule(_reminder('stale'));

    await scheduler.scheduleAll([
      _reminder('r1', days: {Weekday.sunday}),
    ]);

    expect(client.scheduled.values.single.title, 'Reminder r1');
  });

  test('ids are stable and keep reminders apart', () {
    expect(
      LocalNotificationScheduler.baseId('a'),
      LocalNotificationScheduler.baseId('a'),
    );
    expect(
      LocalNotificationScheduler.baseId('a'),
      isNot(LocalNotificationScheduler.baseId('b')),
    );
    expect(LocalNotificationScheduler.baseId('x') % 8, 0);
  });
}
