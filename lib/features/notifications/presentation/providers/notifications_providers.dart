import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';

import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import 'notifications_list_state.dart';

/// All / Unread / Study / Performance / AI / System — the Notification
/// Center's own filter, same "one shared provider every screen reads/
/// writes" shape as `performanceFilterProvider`. Purely a client-side view
/// over [notificationsListNotifierProvider]'s already-fetched items (see
/// [NotificationListFilter.matches]) — never a separate fetch, since the
/// mock/real list is small enough to filter in memory.
class NotificationListFilterNotifier extends Notifier<NotificationListFilter> {
  @override
  NotificationListFilter build() => NotificationListFilter.all;

  void setFilter(NotificationListFilter filter) => state = filter;
}

final notificationListFilterProvider =
    NotifierProvider<NotificationListFilterNotifier, NotificationListFilter>(
      NotificationListFilterNotifier.new,
    );

/// Owns the Notification Center's fetch and every mutation (mark as read/
/// all, delete) — screens only read [NotificationsListState] and call
/// [markAsRead]/[markAllAsRead]/[delete]/[retry], never the repository
/// directly (same rule as AttemptHistoryNotifier).
/// The Notification Center list for the selected filter chip — filtered and
/// paged on the server (contract §A9). Rebuilds from page 1 whenever the
/// filter changes.
class NotificationsListNotifier extends Notifier<NotificationsListState> {
  late NotificationsRepository _repository;

  static const _pageSize = 20;

  @override
  NotificationsListState build() {
    _repository = ref.watch(notificationsRepositoryProvider);
    ref.watch(notificationListFilterProvider);
    // Deferred to a microtask for the same reason
    // AttemptHistoryNotifier.build() defers to `load()`: `state` isn't
    // safe to write to until this `build()` call has actually returned.
    Future.microtask(load);
    return const NotificationsListLoading();
  }

  NotificationListFilter get _filter =>
      ref.read(notificationListFilterProvider);

  Future<void> load() async {
    state = const NotificationsListLoading();
    final result = await _repository.getNotifications(
      limit: _pageSize,
      filter: _filter,
    );
    state = result.when(
      success: (page) => NotificationsListReady(
        page.items,
        page: page.page,
        hasMore: page.hasMore,
      ),
      failure: NotificationsListError.new,
    );
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> retry() => load();

  /// Appends the next page (the list calls this near its end).
  Future<void> loadMore() async {
    final current = state;
    if (current is! NotificationsListReady ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    state = current.copyWith(isLoadingMore: true);
    final result = await _repository.getNotifications(
      page: current.page + 1,
      limit: _pageSize,
      filter: _filter,
    );
    state = result.when(
      success: (page) => NotificationsListReady(
        [...current.items, ...page.items],
        page: page.page,
        hasMore: page.hasMore,
      ),
      // Keeps what's on screen; scrolling down tries again.
      failure: (_) => current.copyWith(isLoadingMore: false),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final result = await _repository.markAsRead(notificationId);
    if (result case Success(value: final read)) {
      final current = state;
      if (current is NotificationsListReady) {
        state = current.copyWith(
          items: [
            for (final n in current.items) n.id == notificationId ? read : n,
          ],
        );
      }
      ref
        ..invalidate(unreadNotificationCountProvider)
        ..invalidate(notificationDetailsProvider(notificationId));
    }
    // A failed mark-as-read keeps the item as-is — tapping again retries.
  }

  Future<void> markAllAsRead() async {
    final current = state;
    if (current is! NotificationsListReady) return;
    final result = await _repository.markAllAsRead();
    if (result is Success<int>) {
      // Under the Unread chip, everything just left the filter.
      await load();
    }
  }

  Future<void> delete(String notificationId) async {
    final current = state;
    if (current is! NotificationsListReady) return;
    final result = await _repository.deleteNotification(notificationId);
    if (result is Success<void>) {
      state = current.copyWith(
        items: current.items.where((n) => n.id != notificationId).toList(),
      );
      ref.invalidate(unreadNotificationCountProvider);
    }
  }
}

final notificationsListNotifierProvider =
    NotifierProvider<NotificationsListNotifier, NotificationsListState>(
      NotificationsListNotifier.new,
    );

/// A notification already in the loaded list, or `null`.
final notificationByIdProvider = Provider.family<NotificationItem?, String>((
  ref,
  id,
) {
  final state = ref.watch(notificationsListNotifierProvider);
  if (state is! NotificationsListReady) return null;
  for (final item in state.items) {
    if (item.id == id) return item;
  }
  return null;
});

/// One notification for its details page: from the loaded list when it's
/// there, otherwise `GET /notifications/:id` (deep links, push taps).
final notificationDetailsProvider = FutureProvider.autoDispose
    .family<NotificationItem, String>((ref, id) async {
      final loaded = ref.read(notificationByIdProvider(id));
      if (loaded != null) return loaded;
      final result = await ref
          .watch(notificationsRepositoryProvider)
          .getNotification(id);
      return switch (result) {
        Success(:final value) => value,
        Failure(:final failure) => throw failure,
      };
    });

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final result = await ref
      .watch(notificationsRepositoryProvider)
      .getUnreadCount();
  return result.when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
});
