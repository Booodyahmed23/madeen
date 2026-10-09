import '../../../../core/error/app_failure.dart';
import '../../domain/entities/notification_item.dart';

/// Notification Center's own state machine — a plain list (no pagination;
/// see docs/MOBILE_API_CONTRACT.md §A9 for
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
  const NotificationsListReady(
    this.items, {
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<NotificationItem> items;

  /// The last page loaded.
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  NotificationsListReady copyWith({
    List<NotificationItem>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) => NotificationsListReady(
    items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class NotificationsListError extends NotificationsListState {
  const NotificationsListError(this.failure);

  final AppFailure failure;
}
