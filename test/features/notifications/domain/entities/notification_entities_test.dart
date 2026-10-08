import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';

void main() {
  group('NotificationItem.copyWith', () {
    test('changes only isRead, keeping every other field', () {
      final item = NotificationItem(
        id: 'notif-1',
        title: 'Title',
        body: 'Body',
        createdAt: DateTime(2026, 9, 25, 8),
        type: NotificationType.studyReminder,
        isRead: false,
        priority: NotificationPriority.high,
        action: NotificationAction(type: NotificationActionType.openExamSetup),
      );

      final updated = item.copyWith(isRead: true);

      expect(updated.isRead, isTrue);
      expect(updated.id, item.id);
      expect(updated.title, item.title);
      expect(updated.priority, item.priority);
      expect(updated.action.type, item.action.type);
    });
  });

  group('NotificationListFilter.matches', () {
    final unread = NotificationItem(
      id: '1',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 9, 25),
      type: NotificationType.studyReminder,
      isRead: false,
    );
    final read = NotificationItem(
      id: '2',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 9, 25),
      type: NotificationType.performanceUpdate,
      isRead: true,
    );
    final exam = NotificationItem(
      id: '3',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 9, 25),
      type: NotificationType.examReminder,
      isRead: true,
    );
    final achievement = NotificationItem(
      id: '4',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 9, 25),
      type: NotificationType.achievement,
      isRead: true,
    );
    final ai = NotificationItem(
      id: '5',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 9, 25),
      type: NotificationType.aiRecommendation,
      isRead: true,
    );
    final system = NotificationItem(
      id: '6',
      title: 't',
      body: 'b',
      createdAt: DateTime(2026, 9, 25),
      type: NotificationType.system,
      isRead: true,
    );

    test('all matches everything', () {
      for (final item in [unread, read, exam, achievement, ai, system]) {
        expect(NotificationListFilter.all.matches(item), isTrue);
      }
    });

    test('unread matches only unread items', () {
      expect(NotificationListFilter.unread.matches(unread), isTrue);
      expect(NotificationListFilter.unread.matches(read), isFalse);
    });

    test('study covers studyReminder and examReminder', () {
      expect(NotificationListFilter.study.matches(unread), isTrue);
      expect(NotificationListFilter.study.matches(exam), isTrue);
      expect(NotificationListFilter.study.matches(read), isFalse);
    });

    test('performance covers performanceUpdate and achievement', () {
      expect(NotificationListFilter.performance.matches(read), isTrue);
      expect(NotificationListFilter.performance.matches(achievement), isTrue);
      expect(NotificationListFilter.performance.matches(ai), isFalse);
    });

    test('ai matches only aiRecommendation', () {
      expect(NotificationListFilter.ai.matches(ai), isTrue);
      expect(NotificationListFilter.ai.matches(read), isFalse);
    });

    test('system matches only system', () {
      expect(NotificationListFilter.system.matches(system), isTrue);
      expect(NotificationListFilter.system.matches(read), isFalse);
    });
  });

  group('NotificationType wire mapping', () {
    test('round-trips every value', () {
      for (final type in NotificationType.values) {
        expect(NotificationType.fromWire(type.toWire()), type);
      }
    });

    test('throws for an unknown value', () {
      expect(
        () => NotificationType.fromWire('NOT_A_TYPE'),
        throwsFormatException,
      );
    });
  });

  group('NotificationPriority wire mapping', () {
    test('round-trips every value', () {
      for (final priority in NotificationPriority.values) {
        expect(NotificationPriority.fromWire(priority.toWire()), priority);
      }
    });
  });

  group('NotificationActionType wire mapping', () {
    test('round-trips every value except unknown', () {
      for (final type in NotificationActionType.values) {
        if (type == NotificationActionType.unknown) continue;
        expect(NotificationActionType.fromWire(type.toWire()), type);
      }
    });

    test('an unrecognized wire value degrades to unknown, never throws', () {
      expect(
        NotificationActionType.fromWire('somethingNew'),
        NotificationActionType.unknown,
      );
    });
  });
}
