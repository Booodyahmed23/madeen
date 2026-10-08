import 'notification_action.dart';
import 'notification_type.dart';

/// One row in the Notification Center — always sourced from
/// [NotificationsRepository], never constructed ad hoc by the UI (same
/// authoritative-data rule every other feature in this app follows for its
/// own domain entities).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    required this.isRead,
    this.priority = NotificationPriority.normal,
    this.action = const NotificationAction(),
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;
  final NotificationPriority priority;
  final NotificationAction action;

  /// When it was first read; `null` while unread.
  final DateTime? readAt;

  NotificationItem copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      type: type,
      isRead: isRead ?? this.isRead,
      priority: priority,
      action: action,
      readAt: readAt ?? this.readAt,
    );
  }
}

/// Which category tab a notification belongs to on the Notification Center
/// — a small, curated grouping over [NotificationType] (not a 1:1 mapping):
/// [study] covers both [NotificationType.studyReminder] and [NotificationType.
/// examReminder] (both are "something to go do"), and [performance] covers
/// both [NotificationType.performanceUpdate] and [NotificationType.
/// achievement] (both are "here's how you're doing"). This keeps the filter
/// bar at the phase brief's four category tabs (Study/Performance/AI/System)
/// rather than one tab per [NotificationType] value.
enum NotificationListFilter {
  all,
  unread,
  study,
  performance,
  system;

  bool matches(NotificationItem item) => switch (this) {
    NotificationListFilter.all => true,
    NotificationListFilter.unread => !item.isRead,
    NotificationListFilter.study =>
      item.type == NotificationType.studyReminder ||
          item.type == NotificationType.examReminder,
    NotificationListFilter.performance =>
      item.type == NotificationType.performanceUpdate ||
          item.type == NotificationType.achievement,
    NotificationListFilter.system => item.type == NotificationType.system,
  };

  /// The API query for this chip (contract §A9) — the list is filtered on
  /// the server, not in memory.
  ({List<String> types, bool unreadOnly}) get query => switch (this) {
    NotificationListFilter.all => (types: const [], unreadOnly: false),
    NotificationListFilter.unread => (types: const [], unreadOnly: true),
    NotificationListFilter.study => (
      types: const ['STUDY_REMINDER', 'EXAM_REMINDER'],
      unreadOnly: false,
    ),
    NotificationListFilter.performance => (
      types: const ['PERFORMANCE_UPDATE', 'ACHIEVEMENT'],
      unreadOnly: false,
    ),
    NotificationListFilter.system => (
      types: const ['SYSTEM'],
      unreadOnly: false,
    ),
  };
}
