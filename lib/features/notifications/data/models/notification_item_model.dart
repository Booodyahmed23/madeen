import '../../domain/entities/notification_action.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_type.dart';

class NotificationItemModel {
  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    required this.isRead,
    this.priority = NotificationPriority.normal,
    this.actionType = NotificationActionType.none,
    this.actionTargetId,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    final action = json['action'] as Map<String, dynamic>?;
    return NotificationItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: NotificationType.fromWire(json['type'] as String),
      isRead: json['isRead'] as bool,
      priority: json['priority'] == null
          ? NotificationPriority.normal
          : NotificationPriority.fromWire(json['priority'] as String),
      actionType: action == null
          ? NotificationActionType.none
          : NotificationActionType.fromWire(action['type'] as String),
      actionTargetId: action == null ? null : action['targetId'] as String?,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;
  final NotificationPriority priority;
  final NotificationActionType actionType;
  final String? actionTargetId;

  NotificationItemModel copyWith({bool? isRead}) => NotificationItemModel(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    type: type,
    isRead: isRead ?? this.isRead,
    priority: priority,
    actionType: actionType,
    actionTargetId: actionTargetId,
  );

  NotificationItem toEntity() => NotificationItem(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    type: type,
    isRead: isRead,
    priority: priority,
    action: NotificationAction(type: actionType, targetId: actionTargetId),
  );
}
