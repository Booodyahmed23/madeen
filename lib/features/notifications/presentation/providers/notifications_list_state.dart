import '../../../../core/error/app_failure.dart';
import '../../domain/entities/notification_item.dart';

/// Notification Center's own state machine — a plain list (no pagination;
/// see NOTIFICATIONS_API_REQUIREMENTS.md's "Pagination requirements" for
/// why the mobile client doesn't need it yet at this feature's expected
/// volume), so this is simpler than AttemptHistoryState: no `loadMore`,
/// just Loading/Ready/Error.
sealed class NotificationsListState {
  const NotificationsListState();
}

class NotificationsListLoading extends NotificationsListState {
  const NotificationsListLoading();
}

class NotificationsListReady extends NotificationsListState {
  const NotificationsListReady(this.items);

  final List<NotificationItem> items;
}

class NotificationsListError extends NotificationsListState {
  const NotificationsListError(this.failure);

  final AppFailure failure;
}
