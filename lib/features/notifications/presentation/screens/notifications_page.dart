import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/notifications_list_state.dart';
import '../providers/notifications_providers.dart';
import '../widgets/notification_filter_chip_bar.dart';
import '../widgets/notification_list_tile.dart';

/// The Notification Center — every notification the student has received,
/// filterable by category, with read/unread state and per-item or bulk
/// mark-as-read. Owns no business logic itself: every action delegates to
/// [notificationsListNotifierProvider] (see that notifier's own doc
/// comment), this screen only renders [NotificationsListState] and the
/// current [NotificationListFilter].
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(notificationsListNotifierProvider);
    final filter = ref.watch(notificationListFilterProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final hasUnread =
        unreadCountAsync.value != null && unreadCountAsync.value! > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (hasUnread)
            // Capped so the title keeps room on narrow phones with large
            // text; the label ellipsizes rather than overflowing the bar.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.45,
              ),
              child: TextButton(
                onPressed: () => ref
                    .read(notificationsListNotifierProvider.notifier)
                    .markAllAsRead(),
                child: Text(
                  l10n.notificationsMarkAllRead,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          NotificationFilterChipBar(
            selected: filter,
            onSelected: (value) => ref
                .read(notificationListFilterProvider.notifier)
                .setFilter(value),
          ),
          Expanded(
            child: switch (state) {
              NotificationsListLoading() => const MadeenPageLoading(),
              NotificationsListError(failure: final failure) => _ErrorView(
                failure: failure,
                onRetry: () => ref
                    .read(notificationsListNotifierProvider.notifier)
                    .retry(),
              ),
              NotificationsListReady(items: final items) => _NotificationsList(
                items: items.where(filter.matches).toList(),
                filter: filter,
                onTapItem: (item) {
                  if (!item.isRead) {
                    ref
                        .read(notificationsListNotifierProvider.notifier)
                        .markAsRead(item.id);
                  }
                  context.push(AppRoutes.notificationDetail(item.id));
                },
                onDismissItem: (item) => ref
                    .read(notificationsListNotifierProvider.notifier)
                    .delete(item.id),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.items,
    required this.filter,
    required this.onTapItem,
    required this.onDismissItem,
  });

  final List<NotificationItem> items;
  final NotificationListFilter filter;
  final ValueChanged<NotificationItem> onTapItem;
  final ValueChanged<NotificationItem> onDismissItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (items.isEmpty) {
      final message = filter == NotificationListFilter.all
          ? l10n.notificationsEmptyAll
          : filter == NotificationListFilter.unread
          ? l10n.notificationsEmptyUnread
          : l10n.notificationsEmptyFiltered;
      return MadeenPageMessage(
        message: message,
        icon: Icons.notifications_none_outlined,
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: MadeenSpace.pageMargin,
        endIndent: MadeenSpace.pageMargin,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return NotificationListTile(
          notification: item,
          onTap: () => onTapItem(item),
          onDismiss: () => onDismissItem(item),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MadeenPageMessage(
      message: failure.message,
      isError: true,
      actionLabel: l10n.notificationsRetryButton,
      onAction: onRetry,
    );
  }
}
