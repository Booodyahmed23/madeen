import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/notification_item.dart';

/// The Notification Center's All / Unread / Study / Performance / AI /
/// System row — a thin view over [NotificationListFilter], never owning
/// state itself (the selected filter lives in
/// `notificationListFilterProvider`, same "provider owns it, widget only
/// renders it" split every other filter bar in this app follows, e.g.
/// `AttemptTypeFilterBar`).
class NotificationFilterChipBar extends StatelessWidget {
  const NotificationFilterChipBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NotificationListFilter selected;
  final ValueChanged<NotificationListFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = {
      NotificationListFilter.all: l10n.notificationsFilterAll,
      NotificationListFilter.unread: l10n.notificationsFilterUnread,
      NotificationListFilter.study: l10n.notificationsFilterStudy,
      NotificationListFilter.performance: l10n.notificationsFilterPerformance,
      NotificationListFilter.ai: l10n.notificationsFilterAi,
      NotificationListFilter.system: l10n.notificationsFilterSystem,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: MadeenSpace.pageMargin,
        vertical: MadeenSpace.xs,
      ),
      child: Row(
        children: [
          for (final entry in options.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelected(entry.key),
            ),
            const SizedBox(width: MadeenSpace.xs),
          ],
        ],
      ),
    );
  }
}
