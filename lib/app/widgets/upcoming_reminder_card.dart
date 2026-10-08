import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../features/notifications/presentation/providers/study_reminders_providers.dart';
import '../../features/notifications/presentation/providers/study_reminders_state.dart';
import '../../features/notifications/presentation/widgets/study_reminder_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/madeen/madeen.dart';
import '../next_study_reminder.dart';

/// Home's Upcoming Study Reminder — reads the exact same
/// [studyRemindersNotifierProvider] the Study Reminders screen owns, then
/// applies the pure, unpersisted [nextStudyReminder] view over it (see that
/// function's own doc comment). Never a second reminders data source.
///
/// Presented as the reference's "milestone" panel: a calendar date block
/// beside the reminder's title and time.
class UpcomingReminderCard extends ConsumerWidget {
  const UpcomingReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final state = ref.watch(studyRemindersNotifierProvider);

    return MadeenCard(
      onTap: () => context.push(AppRoutes.studyReminders),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(
            title: l10n.homeUpcomingReminderTitle,
            trailing: Icon(
              Icons.event_outlined,
              size: 20,
              color: t.inkSecondary,
            ),
          ),
          const SizedBox(height: MadeenSpace.sm),
          switch (state) {
            StudyRemindersLoading() => const MadeenLoadingState(),
            StudyRemindersError() => MadeenErrorState(
              message: l10n.studyRemindersGenericError,
              retryLabel: l10n.studyRemindersRetryButton,
              onRetry: () =>
                  ref.read(studyRemindersNotifierProvider.notifier).retry(),
            ),
            StudyRemindersReady(reminders: final reminders) => _ReadyBody(
              next: nextStudyReminder(reminders, DateTime.now()),
            ),
          },
        ],
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.next});

  final NextStudyReminder? next;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final next = this.next;

    if (next == null) {
      return MadeenEmptyState(
        message: l10n.homeNoUpcomingReminder,
        action: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => context.push(AppRoutes.studyReminders),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(l10n.homeManageReminders),
          ),
        ),
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final dayLabel = DateFormat.EEEE(locale).format(next.occursAt);
    final timeLabel = formatReminderTime(
      context,
      next.reminder.hour,
      next.reminder.minute,
    );

    return Container(
      padding: const EdgeInsets.all(MadeenSpace.sm),
      decoration: BoxDecoration(
        color: t.neutralFill,
        borderRadius: BorderRadius.circular(MadeenRadius.base),
      ),
      child: Row(
        children: [
          MadeenDateBlock(date: next.occursAt),
          const SizedBox(width: MadeenSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next.reminder.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MadeenType.headlineSm.copyWith(color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.homeUpcomingReminderWhen(dayLabel, timeLabel),
                  style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
