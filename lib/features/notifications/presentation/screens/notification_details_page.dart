import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_type.dart';
import '../navigation/notification_action_resolver.dart';
import '../providers/notifications_providers.dart';
import '../widgets/notification_format.dart';

/// A single notification's full detail — title, body, type, timestamp,
/// priority, and (when [NotificationActionResolver] can resolve one) a
/// primary CTA that navigates there. Reads [notificationByIdProvider]
/// rather than fetching its own copy (see that provider's doc comment for
/// why): this screen only ever shows what
/// [notificationsListNotifierProvider] already fetched.
class NotificationDetailsPage extends ConsumerStatefulWidget {
  const NotificationDetailsPage({super.key, required this.notificationId});

  final String notificationId;

  @override
  ConsumerState<NotificationDetailsPage> createState() =>
      _NotificationDetailsPageState();
}

class _NotificationDetailsPageState
    extends ConsumerState<NotificationDetailsPage> {
  bool _markedAsRead = false;

  void _maybeMarkAsRead(NotificationItem? item) {
    if (_markedAsRead || item == null || item.isRead) return;
    _markedAsRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsListNotifierProvider.notifier).markAsRead(item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The loaded copy wins (it reflects mark-as-read at once); otherwise
    // the notification is fetched on its own.
    final loaded = ref.watch(notificationByIdProvider(widget.notificationId));
    final details = ref.watch(
      notificationDetailsProvider(widget.notificationId),
    );
    final item = loaded ?? details.value;

    _maybeMarkAsRead(item);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationDetailsTitle)),
      body: switch ((item, details)) {
        (final NotificationItem item, _) => _DetailsBody(item: item),
        (_, AsyncError(error: NotFoundFailure())) => const _NotFoundView(),
        (_, AsyncError(error: final AppFailure failure)) => _ErrorView(
          failure: failure,
          onRetry: () => ref.invalidate(
            notificationDetailsProvider(widget.notificationId),
          ),
        ),
        (_, AsyncError()) => const _NotFoundView(),
        _ => const MadeenPageLoading(),
      },
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final route = NotificationActionResolver.resolve(item.action);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: MadeenSize.iconWell + 4,
                height: MadeenSize.iconWell + 4,
                decoration: BoxDecoration(
                  color: t.neutralFill,
                  borderRadius: BorderRadius.circular(MadeenRadius.base),
                ),
                child: Icon(
                  notificationTypeIcon(item.type),
                  color: t.inkSecondary,
                ),
              ),
              const SizedBox(width: MadeenSpace.sm),
              Expanded(
                child: Text(
                  item.title,
                  textDirection: notificationTextLayout(
                    context,
                    item.title,
                  ).direction,
                  textAlign: notificationTextLayout(context, item.title).align,
                  style: Theme.of(context).textTheme.headlineMedium!
                      .copyWith(color: t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: MadeenSpace.md),
          Text(
            item.body,
            textDirection: notificationTextLayout(context, item.body).direction,
            textAlign: notificationTextLayout(context, item.body).align,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: t.ink),
          ),
          const SizedBox(height: MadeenSpace.lg),
          MadeenCard(
            padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.md),
            child: MadeenDividedList(
              children: [
                _DetailRow(
                  label: l10n.notificationDetailsTypeLabel,
                  value: notificationTypeLabel(l10n, item.type),
                ),
                _DetailRow(
                  label: l10n.notificationDetailsDateLabel,
                  value: formatNotificationTimestamp(context, item.createdAt),
                ),
                if (item.priority == NotificationPriority.high)
                  _DetailRow(
                    label: l10n.notificationDetailsPriorityLabel,
                    value: l10n.notificationsPriorityHigh,
                  ),
              ],
            ),
          ),
          const SizedBox(height: MadeenSpace.lg),
          if (route != null)
            SizedBox(
              height: MadeenSize.buttonHeight,
              child: FilledButton(
                onPressed: () => context.push(route),
                child: Text(l10n.notificationDetailsOpenButton),
              ),
            )
          else
            Text(
              l10n.notificationDetailsNoAction,
              style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MadeenSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
            ),
          ),
          const SizedBox(width: MadeenSpace.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: MadeenType.bodyMd.copyWith(
                color: t.ink,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MadeenSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 32, color: t.inkTertiary),
            const SizedBox(height: MadeenSpace.sm),
            Text(
              l10n.notificationDetailsNotFoundTitle,
              style: Theme.of(context).textTheme.titleLarge!
                  .copyWith(color: t.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MadeenSpace.xs),
            Text(
              l10n.notificationDetailsNotFoundMessage,
              style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MadeenSpace.md),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: Text(l10n.notificationDetailsBackButton),
            ),
          ],
        ),
      ),
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
      message: localizedFailureMessage(AppLocalizations.of(context)!, failure),
      isError: true,
      actionLabel: l10n.notificationsRetryButton,
      onAction: onRetry,
    );
  }
}
