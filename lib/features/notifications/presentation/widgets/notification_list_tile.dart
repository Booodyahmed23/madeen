import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_type.dart';
import 'notification_format.dart';

/// One row in the Notification Center — read once here, reused by
/// [NotificationsPage] only (no other screen shows a list of these).
/// Unread state is deliberately subtle (a filled dot + slightly bolder
/// title, never a background color wash) per this feature's own "unread
/// state should be calm" UI direction, and priority is a small text badge
/// — never conveyed through color alone — so both remain legible under any
/// contrast setting and to a screen reader.
class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final isUnread = !notification.isRead;
    final typeLabel = notificationTypeLabel(l10n, notification.type);
    final timestamp = formatNotificationTimestamp(
      context,
      notification.createdAt,
    );

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.pageMargin),
        color: t.error,
        child: Icon(Icons.delete_outline, color: t.surface),
      ),
      child: Semantics(
        button: true,
        label: isUnread
            ? '$typeLabel. ${l10n.notificationsUnreadLabel}'
            : typeLabel,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MadeenSpace.pageMargin,
              vertical: MadeenSpace.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: MadeenSize.iconWell,
                  height: MadeenSize.iconWell,
                  decoration: BoxDecoration(
                    color: t.neutralFill,
                    borderRadius: BorderRadius.circular(MadeenRadius.base),
                  ),
                  child: Icon(
                    notificationTypeIcon(notification.type),
                    color: t.inkSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: MadeenSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              textDirection: notificationTextLayout(
                                context,
                                notification.title,
                              ).direction,
                              textAlign: notificationTextLayout(
                                context,
                                notification.title,
                              ).align,
                              style: MadeenType.bodyMd.copyWith(
                                color: t.ink,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (notification.priority ==
                              NotificationPriority.high) ...[
                            const SizedBox(width: MadeenSpace.xs),
                            Flexible(
                              child: _PriorityBadge(
                                label: l10n.notificationsPriorityHigh,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        textDirection: notificationTextLayout(
                          context,
                          notification.body,
                        ).direction,
                        textAlign: notificationTextLayout(
                          context,
                          notification.body,
                        ).align,
                        style: MadeenType.bodySm.copyWith(
                          color: t.inkSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MadeenSpace.xxs),
                      Text(
                        timestamp,
                        style: MadeenType.labelMd.copyWith(
                          color: t.inkTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 6,
                      start: MadeenSpace.xs,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MadeenRadius.pill),
        border: Border.all(color: t.attention),
      ),
      child: Text(
        label,
        style: MadeenType.labelSm.copyWith(color: t.attention),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
