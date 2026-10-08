import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/models/notification_item_model.dart';
import 'package:mobile/features/notifications/data/models/notification_preferences_model.dart';
import 'package:mobile/features/notifications/data/models/study_reminder_model.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';
import 'package:mobile/features/notifications/domain/entities/weekday.dart';

void main() {
  test('parses an API notification with an OPEN_ATTEMPT action', () {
    final item = notificationFromJson({
      'id': 'n1',
      'type': 'PERFORMANCE_UPDATE',
      'priority': 'NORMAL',
      'title': 'Exam submitted',
      'body': 'You got 1 of 4 correct (25%).',
      'action': {
        'type': 'OPEN_ATTEMPT',
        'targetId': 'a1',
        'attemptType': 'EXAM',
      },
      'isRead': false,
      'readAt': null,
      'createdAt': '2026-10-08T21:02:17.299Z',
    });

    expect(item.type, NotificationType.performanceUpdate);
    expect(item.action.type, NotificationActionType.openAttempt);
    expect(item.action.targetId, 'a1');
    expect(item.action.attemptType, 'EXAM');
    expect(item.readAt, isNull);
  });

  test('a null action and an unknown type parse without error', () {
    final item = notificationFromJson({
      'id': 'n2',
      'type': 'SOMETHING_NEW',
      'priority': 'LOW',
      'title': 't',
      'body': 'b',
      'action': null,
      'isRead': true,
      'readAt': '2026-10-08T22:00:00.000Z',
      'createdAt': '2026-10-08T21:00:00.000Z',
    });

    expect(item.type, NotificationType.unknown);
    expect(item.action.type, NotificationActionType.none);
    expect(item.readAt, DateTime.utc(2026, 10, 8, 22));
  });

  test('notificationToJson writes the API shape back', () {
    final json = {
      'id': 'n1',
      'type': 'SYSTEM',
      'priority': 'HIGH',
      'title': 't',
      'body': 'b',
      'action': {'type': 'OPEN_PLANS'},
      'isRead': false,
      'readAt': null,
      'createdAt': '2026-10-08T21:00:00.000Z',
    };

    expect(notificationToJson(notificationFromJson(json)), json);
  });

  test('preferences have seven keys and send only what changed', () {
    const before = NotificationPreferences();
    final after = before.copyWith(achievements: false);

    expect(notificationPreferencesToJson(before).keys, hasLength(7));
    expect(
      notificationPreferencesToJson(before).containsKey('aiRecommendations'),
      isFalse,
    );
    expect(notificationPreferencesChanges(before, after), {
      'achievements': false,
    });
  });

  test('a reminder parses updatedAt', () {
    final reminder = StudyReminderModel.fromJson({
      'id': 'r1',
      'title': 'Daily CMA practice',
      'enabled': true,
      'hour': 7,
      'minute': 30,
      'repeat': 'CUSTOM',
      'customDays': ['MON', 'WED'],
      'notificationType': 'STUDY_REMINDER',
      'createdAt': '2026-10-08T21:17:56.944Z',
      'updatedAt': '2026-10-08T21:20:00.000Z',
    }).toEntity();

    expect(reminder.customDays, {Weekday.monday, Weekday.wednesday});
    expect(reminder.updatedAt, DateTime.utc(2026, 10, 8, 21, 20));
  });

  test('a draft sends no custom days unless it repeats on custom days', () {
    const draft = StudyReminderDraft(
      title: '  Review  ',
      enabled: true,
      hour: 8,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
      customDays: {Weekday.monday},
    );

    final json = studyReminderDraftToJson(draft);
    expect(json['title'], 'Review');
    expect(json['customDays'], isEmpty);
    expect(json.containsKey('id'), isFalse);
  });
}
