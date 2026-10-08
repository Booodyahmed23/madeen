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
  group('NotificationItemModel', () {
    test('fromJson reads every field, defaulting priority/action', () {
      final model = NotificationItemModel.fromJson({
        'id': 'notif-1',
        'title': 'Title',
        'body': 'Body',
        'createdAt': '2026-09-25T08:00:00.000Z',
        'type': 'STUDY_REMINDER',
        'isRead': false,
      });

      expect(model.id, 'notif-1');
      expect(model.priority, NotificationPriority.normal);
      expect(model.actionType, NotificationActionType.none);
      expect(model.actionTargetId, isNull);
    });

    test('fromJson reads an explicit priority and action', () {
      final model = NotificationItemModel.fromJson({
        'id': 'notif-2',
        'title': 'Title',
        'body': 'Body',
        'createdAt': '2026-09-25T08:00:00.000Z',
        'type': 'AI_RECOMMENDATION',
        'isRead': false,
        'priority': 'HIGH',
        'action': {'type': 'openAttemptDetails', 'targetId': 'attempt-1'},
      });

      expect(model.priority, NotificationPriority.high);
      expect(model.actionType, NotificationActionType.openAttemptDetails);
      expect(model.actionTargetId, 'attempt-1');
    });

    test('toEntity carries every field across, wrapping action', () {
      final model = NotificationItemModel(
        id: 'notif-1',
        title: 'Title',
        body: 'Body',
        createdAt: DateTime(2026, 9, 25, 8),
        type: NotificationType.system,
        isRead: true,
        priority: NotificationPriority.low,
        actionType: NotificationActionType.openExamSetup,
      );

      final entity = model.toEntity();
      expect(entity.id, model.id);
      expect(entity.isRead, isTrue);
      expect(entity.action.type, NotificationActionType.openExamSetup);
    });

    test('copyWith changes only isRead', () {
      final model = NotificationItemModel(
        id: 'notif-1',
        title: 'Title',
        body: 'Body',
        createdAt: DateTime(2026, 9, 25, 8),
        type: NotificationType.system,
        isRead: false,
      );

      expect(model.copyWith(isRead: true).isRead, isTrue);
      expect(model.copyWith(isRead: true).id, model.id);
    });
  });

  group('NotificationPreferencesModel', () {
    const entity = NotificationPreferences(
      studyReminders: false,
      dailyStudyReminders: true,
      examReminders: false,
      simulationReminders: true,
      performanceUpdates: false,
      aiRecommendations: true,
      achievements: false,
      systemNotifications: true,
    );

    test('fromEntity / toEntity round-trips every field', () {
      final model = NotificationPreferencesModel.fromEntity(entity);
      final roundTripped = model.toEntity();

      expect(roundTripped.studyReminders, entity.studyReminders);
      expect(roundTripped.dailyStudyReminders, entity.dailyStudyReminders);
      expect(roundTripped.examReminders, entity.examReminders);
      expect(roundTripped.simulationReminders, entity.simulationReminders);
      expect(roundTripped.performanceUpdates, entity.performanceUpdates);
      expect(roundTripped.aiRecommendations, entity.aiRecommendations);
      expect(roundTripped.achievements, entity.achievements);
      expect(roundTripped.systemNotifications, entity.systemNotifications);
    });

    test('toJson / fromJson round-trips every field', () {
      final model = NotificationPreferencesModel.fromEntity(entity);
      final roundTripped = NotificationPreferencesModel.fromJson(
        model.toJson(),
      );

      expect(roundTripped.toJson(), model.toJson());
    });
  });

  group('StudyReminderModel', () {
    test('fromJson / toJson round-trips a custom-repeat reminder', () {
      final json = {
        'id': 'reminder-1',
        'title': 'Daily CMA Practice',
        'enabled': true,
        'hour': 7,
        'minute': 30,
        'repeat': 'CUSTOM',
        'customDays': ['MON', 'WED', 'FRI'],
        'notificationType': 'EXAM_REMINDER',
        'createdAt': '2026-09-01T07:30:00.000Z',
      };

      final model = StudyReminderModel.fromJson(json);
      expect(model.repeat, ReminderRepeat.custom);
      expect(model.customDays, {
        Weekday.monday,
        Weekday.wednesday,
        Weekday.friday,
      });
      expect(model.notificationType, NotificationType.examReminder);
      expect(model.toJson(), json);
    });

    test('fromJson defaults customDays/notificationType when omitted', () {
      final model = StudyReminderModel.fromJson({
        'id': 'reminder-2',
        'title': 'Practice',
        'enabled': true,
        'hour': 8,
        'minute': 0,
        'repeat': 'EVERY_DAY',
        'createdAt': '2026-09-01T08:00:00.000Z',
      });

      expect(model.customDays, isEmpty);
      expect(model.notificationType, NotificationType.studyReminder);
    });

    test('copyWith changes only enabled', () {
      final model = StudyReminderModel.fromJson({
        'id': 'reminder-1',
        'title': 'Practice',
        'enabled': true,
        'hour': 8,
        'minute': 0,
        'repeat': 'EVERY_DAY',
        'createdAt': '2026-09-01T08:00:00.000Z',
      });
      final disabled = model.copyWith(enabled: false);

      expect(disabled.enabled, isFalse);
      expect(disabled.title, model.title);
    });

    test('studyReminderDraftToJson never includes id/createdAt', () {
      const draft = StudyReminderDraft(
        title: 'Practice',
        enabled: true,
        hour: 8,
        minute: 0,
        repeat: ReminderRepeat.everyDay,
      );

      final json = studyReminderDraftToJson(draft);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
      expect(json['repeat'], 'EVERY_DAY');
    });
  });
}
