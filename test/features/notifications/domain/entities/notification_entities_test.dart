import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';

NotificationItem _item(NotificationType type, {bool isRead = false}) =>
    NotificationItem(
      id: type.name,
      title: 't',
      body: 'b',
      createdAt: DateTime.utc(2026, 10, 8),
      type: type,
      isRead: isRead,
    );

void main() {
  test('copyWith marks read and keeps every other field', () {
    final read = _item(NotificationType.system)
        .copyWith(isRead: true, readAt: DateTime.utc(2026, 10, 9));

    expect(read.isRead, isTrue);
    expect(read.readAt, DateTime.utc(2026, 10, 9));
    expect(read.type, NotificationType.system);
  });

  test('each filter chip maps to its API query', () {
    expect(NotificationListFilter.all.query.types, isEmpty);
    expect(NotificationListFilter.all.query.unreadOnly, isFalse);
    expect(NotificationListFilter.unread.query.unreadOnly, isTrue);
    expect(NotificationListFilter.study.query.types, [
      'STUDY_REMINDER',
      'EXAM_REMINDER',
    ]);
    expect(NotificationListFilter.performance.query.types, [
      'PERFORMANCE_UPDATE',
      'ACHIEVEMENT',
    ]);
    expect(NotificationListFilter.system.query.types, ['SYSTEM']);
  });

  test('matches agrees with the query (used by sample data)', () {
    expect(
      NotificationListFilter.performance.matches(
        _item(NotificationType.achievement),
      ),
      isTrue,
    );
    expect(
      NotificationListFilter.unread.matches(
        _item(NotificationType.system, isRead: true),
      ),
      isFalse,
    );
  });

  test('an unknown notification type never throws', () {
    expect(NotificationType.fromWire('NEW_KIND'), NotificationType.unknown);
    for (final type in NotificationType.values) {
      if (type == NotificationType.unknown) continue;
      expect(NotificationType.fromWire(type.toWire()), type);
    }
  });

  test('action types use the API names; unknown ones degrade', () {
    for (final type in NotificationActionType.values) {
      final wire = type.toWire();
      if (wire == null) continue;
      expect(NotificationActionType.fromWire(wire), type);
    }
    expect(
      NotificationActionType.fromWire('openAiAnalysisOverview'),
      NotificationActionType.unknown,
    );
  });
}
