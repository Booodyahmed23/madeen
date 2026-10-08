import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/notifications/data/datasources/notifications_mock_data_source.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';

void main() {
  late NotificationsMockDataSource source;

  setUp(() => source = NotificationsMockDataSource());

  Future<List<Map<String, dynamic>>> list({
    List<String> types = const [],
    bool unreadOnly = false,
  }) async {
    final page = await source.getNotifications(
      page: 1,
      limit: 20,
      types: types,
      unreadOnly: unreadOnly,
    );
    return (page['data'] as List).cast<Map<String, dynamic>>();
  }

  test('lists newest first as a { data, meta } page', () async {
    final page = await source.getNotifications(
      page: 1,
      limit: 2,
      types: const [],
      unreadOnly: false,
    );

    expect(page['data'] as List, hasLength(2));
    expect((page['meta'] as Map)['totalPages'], greaterThan(1));
  });

  test('filters by type and unread like the API', () async {
    final system = await list(types: const ['SYSTEM']);
    expect(system.every((n) => n['type'] == 'SYSTEM'), isTrue);

    final unread = await list(unreadOnly: true);
    expect(unread.every((n) => n['isRead'] == false), isTrue);
    expect(unread.length, await source.getUnreadCount());
  });

  test('mark as read sets readAt; read-all reports how many changed', () async {
    final first = (await list(unreadOnly: true)).first;
    final read = await source.markAsRead(first['id'] as String);
    expect(read['isRead'], isTrue);
    expect(read['readAt'], isNotNull);

    final updated = await source.markAllAsRead();
    expect(updated, greaterThan(0));
    expect(await source.getUnreadCount(), 0);
  });

  test('an unknown id is a 404', () async {
    await expectLater(
      source.getNotification('missing'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('preferences update only the sent keys', () async {
    final saved = await source.updateNotificationPreferences({
      'achievements': false,
    });

    expect(saved['achievements'], isFalse);
    expect(saved['studyReminders'], isTrue);
    expect(saved, hasLength(7));
  });

  test('a 21st reminder is rejected with REMINDER_LIMIT_REACHED', () async {
    const draft = StudyReminderDraft(
      title: 'Extra',
      enabled: true,
      hour: 9,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );
    final existing = (await source.getStudyReminders()).length;
    for (var i = existing; i < 20; i++) {
      await source.createStudyReminder(draft);
    }

    await expectLater(
      source.createStudyReminder(draft),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'REMINDER_LIMIT_REACHED')
            .having((e) => e.details, 'details', {'max': 20}),
      ),
    );
  });
}
