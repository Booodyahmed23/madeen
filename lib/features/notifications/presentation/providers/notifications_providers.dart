import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class NotificationsListNotifier extends Notifier<NotificationsListState> {
  late NotificationsRepository _repository;

  @override
  NotificationsListState build() {
    _repository = ref.watch(notificationsRepositoryProvider);
    // Deferred to a microtask for the same reason
    // AttemptHistoryNotifier.build() defers to `load()`: `state` isn't
    // safe to write to until this `build()` call has actually returned.
    Future.microtask(load);
    return const NotificationsListLoading();
  }

  Future<void> load() async {
    state = const NotificationsListLoading();
    final result = await _repository.getNotifications();
    state = result.when(
      success: NotificationsListReady.new,
      failure: NotificationsListError.new,
    );
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> retry() => load();

  Future<void> markAsRead(String notificationId) async {
    final current = state;
    if (current is! NotificationsListReady) return;

    final result = await _repository.markAsRead(notificationId);
    result.when(
      success: (_) {
        state = NotificationsListReady([
          for (final n in current.items)
            if (n.id == notificationId) n.copyWith(isRead: true) else n,
        ]);
        ref.invalidate(unreadNotificationCountProvider);
      },
      // A failed mark-as-read keeps the item as-is rather than showing a
      // full error state — the student can simply tap it again.
      failure: (_) {},
    );
  }

  Future<void> markAllAsRead() async {
    final current = state;
    if (current is! NotificationsListReady) return;

    final result = await _repository.markAllAsRead();
    result.when(
      success: (_) {
        state = NotificationsListReady([
          for (final n in current.items) n.copyWith(isRead: true),
        ]);
        ref.invalidate(unreadNotificationCountProvider);
      },
      failure: (_) {},
    );
  }

  Future<void> delete(String notificationId) async {
    final current = state;
    if (current is! NotificationsListReady) return;

    final result = await _repository.deleteNotification(notificationId);
    result.when(
      success: (_) {
        state = NotificationsListReady(
          current.items.where((n) => n.id != notificationId).toList(),
        );
        ref.invalidate(unreadNotificationCountProvider);
      },
      failure: (_) {},
    );
  }
}

final notificationsListNotifierProvider =
    NotifierProvider<NotificationsListNotifier, NotificationsListState>(
      NotificationsListNotifier.new,
    );

/// One notification looked up by id from whatever
/// [notificationsListNotifierProvider] currently holds — backs
/// NotificationDetailsPage, deliberately *not* a second fetch (this
/// feature's repository has no single-item `getNotification(id)` method;
/// the list is the one source of truth an id is looked up against, same
/// "don't add a method the phase brief's contract didn't ask for" instinct
/// applied elsewhere in this app). `null` while the list is still loading/
/// erred, or if `id` genuinely isn't in it — NotificationDetailsPage
/// renders each of those distinctly rather than treating them the same.
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

/// Independent of [notificationsListNotifierProvider] on purpose — Home's
/// badge must show a real count starting from a cold app launch, before
/// the student has ever opened the Notification Center (which is when
/// [notificationsListNotifierProvider] would first fetch). Every mutation
/// in [NotificationsListNotifier] invalidates this explicitly so the badge
/// stays in sync without polling.
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
