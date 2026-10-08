import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/study_reminder.dart';
import '../providers/study_reminders_providers.dart';
import '../providers/study_reminders_state.dart';
import '../widgets/study_reminder_tile.dart';

/// Every student-configured [StudyReminder], with enable/disable, edit and
/// delete — a thin view over [studyRemindersNotifierProvider], never
/// mutating the repository or `NotificationScheduler` directly.
class StudyRemindersPage extends ConsumerWidget {
  const StudyRemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(studyRemindersNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studyRemindersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.studyReminderNew),
        icon: const Icon(Icons.add),
        label: Text(l10n.studyRemindersAddButton),
      ),
      body: switch (state) {
        StudyRemindersLoading() => const MadeenPageLoading(),
        StudyRemindersError(failure: final failure) => _ErrorView(
          failure: failure,
          onRetry: () =>
              ref.read(studyRemindersNotifierProvider.notifier).retry(),
        ),
        StudyRemindersReady(reminders: final reminders) =>
          reminders.isEmpty
              ? MadeenPageMessage(
                  message: l10n.studyRemindersEmpty,
                  icon: Icons.alarm_outlined,
                )
              : ListView.separated(
                  // Bottom inset clears the extended FAB.
                  padding: const EdgeInsets.fromLTRB(
                    MadeenSpace.pageMargin,
                    MadeenSpace.xs,
                    MadeenSpace.pageMargin,
                    96,
                  ),
                  itemCount: reminders.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return StudyReminderTile(
                      reminder: reminder,
                      onTap: () => context.push(
                        AppRoutes.studyReminderEdit(reminder.id),
                      ),
                      onToggle: (enabled) => ref
                          .read(studyRemindersNotifierProvider.notifier)
                          .toggle(reminder.id, enabled),
                      onDelete: () => _confirmDelete(context, ref, reminder),
                    );
                  },
                ),
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StudyReminder reminder,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.studyRemindersDeleteConfirmTitle),
        content: Text(l10n.studyRemindersDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.notificationsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.studyRemindersDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(studyRemindersNotifierProvider.notifier)
          .delete(reminder.id);
    }
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
      actionLabel: l10n.studyRemindersRetryButton,
      onAction: onRetry,
    );
  }
}
