import '../../domain/entities/notification_action.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_type.dart';

/// The API's Notification object (contract §A9):
/// `{ id, type, priority, title, body, action: { type, targetId?,
/// attemptType? } | null, isRead, readAt, createdAt }`. Unknown `type` and
/// `action.type` values degrade instead of throwing.
NotificationItem notificationFromJson(Map<String, dynamic> json) {
  final action = json['action'] as Map<String, dynamic>?;
  final readAt = json['readAt'] as String?;
  return NotificationItem(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    type: NotificationType.fromWire(json['type'] as String),
    isRead: json['isRead'] as bool,
    readAt: readAt == null ? null : DateTime.parse(readAt),
    priority: switch (json['priority']) {
      'LOW' => NotificationPriority.low,
      'HIGH' => NotificationPriority.high,
      _ => NotificationPriority.normal,
    },
    action: action == null
        ? const NotificationAction()
        : NotificationAction(
            type: NotificationActionType.fromWire(action['type'] as String),
            targetId: action['targetId'] as String?,
            attemptType: action['attemptType'] as String?,
          ),
  );
}

/// The same object as JSON — the mock data source builds the API's shape
/// with it.
Map<String, dynamic> notificationToJson(NotificationItem item) => {
  'id': item.id,
  'type': item.type.toWire(),
  'priority': item.priority.toWire(),
  'title': item.title,
  'body': item.body,
  'action': item.action.type.toWire() == null
      ? null
      : {
          'type': item.action.type.toWire(),
          'targetId': ?item.action.targetId,
          'attemptType': ?item.action.attemptType,
        },
  'isRead': item.isRead,
  'readAt': item.readAt?.toIso8601String(),
  'createdAt': item.createdAt.toIso8601String(),
};
