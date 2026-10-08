import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/notification_preferences.dart';
import '../providers/notification_preferences_providers.dart';
import '../providers/notification_preferences_state.dart';

/// Every Notification Preferences toggle, grouped Study / Exams /
/// Performance / AI / Achievements / System — a thin view over
/// [notificationPreferencesNotifierProvider.setPreferences], never writing
/// to [NotificationsRepository] directly.
class NotificationPreferencesPage extends ConsumerWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(notificationPreferencesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationPreferencesTitle)),
      body: switch (state) {
        NotificationPreferencesLoading() => const MadeenPageLoading(),
        NotificationPreferencesError(failure: final failure) => _ErrorView(
          failure: failure,
          onRetry: () => ref
              .read(notificationPreferencesNotifierProvider.notifier)
              .retry(),
        ),
        NotificationPreferencesReady(
          preferences: final preferences,
          saveError: final saveError,
        ) =>
          _PreferencesList(preferences: preferences, saveError: saveError),
      },
    );
  }
}

class _PreferencesList extends ConsumerWidget {
  const _PreferencesList({required this.preferences, this.saveError});

  final NotificationPreferences preferences;
  final AppFailure? saveError;

  void _update(
    WidgetRef ref,
    NotificationPreferences Function(NotificationPreferences) apply,
  ) {
    ref
        .read(notificationPreferencesNotifierProvider.notifier)
        .setPreferences(apply(preferences));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final t = MadeenTokens.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.xs,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        if (saveError != null)
          Padding(
            padding: const EdgeInsets.only(top: MadeenSpace.sm),
            child: Text(
              l10n.notificationPreferencesUpdateError,
              style: MadeenType.bodySm.copyWith(color: t.error),
            ),
          ),
        _Section(
          title: l10n.notificationPreferencesSectionStudy,
          children: [
            _PreferenceSwitch(
              title: l10n.notificationPreferencesStudyReminders,
              subtitle: l10n.notificationPreferencesStudyRemindersSubtitle,
              value: preferences.studyReminders,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(studyReminders: v)),
            ),
            _PreferenceSwitch(
              title: l10n.notificationPreferencesDailyStudyReminders,
              subtitle: l10n.notificationPreferencesDailyStudyRemindersSubtitle,
              value: preferences.dailyStudyReminders,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(dailyStudyReminders: v)),
            ),
          ],
        ),
        _Section(
          title: l10n.notificationPreferencesSectionExams,
          children: [
            _PreferenceSwitch(
              title: l10n.notificationPreferencesExamReminders,
              subtitle: l10n.notificationPreferencesExamRemindersSubtitle,
              value: preferences.examReminders,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(examReminders: v)),
            ),
            _PreferenceSwitch(
              title: l10n.notificationPreferencesSimulationReminders,
              subtitle: l10n.notificationPreferencesSimulationRemindersSubtitle,
              value: preferences.simulationReminders,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(simulationReminders: v)),
            ),
          ],
        ),
        _Section(
          title: l10n.notificationPreferencesSectionPerformance,
          children: [
            _PreferenceSwitch(
              title: l10n.notificationPreferencesPerformanceUpdates,
              subtitle: l10n.notificationPreferencesPerformanceUpdatesSubtitle,
              value: preferences.performanceUpdates,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(performanceUpdates: v)),
            ),
          ],
        ),
        _Section(
          title: l10n.notificationPreferencesSectionAi,
          children: [
            _PreferenceSwitch(
              title: l10n.notificationPreferencesAiRecommendations,
              subtitle: l10n.notificationPreferencesAiRecommendationsSubtitle,
              value: preferences.aiRecommendations,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(aiRecommendations: v)),
            ),
          ],
        ),
        _Section(
          title: l10n.notificationPreferencesSectionAchievements,
          children: [
            _PreferenceSwitch(
              title: l10n.notificationPreferencesAchievements,
              subtitle: l10n.notificationPreferencesAchievementsSubtitle,
              value: preferences.achievements,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(achievements: v)),
            ),
          ],
        ),
        _Section(
          title: l10n.notificationPreferencesSectionSystem,
          children: [
            _PreferenceSwitch(
              title: l10n.notificationPreferencesSystemNotifications,
              subtitle: l10n.notificationPreferencesSystemNotificationsSubtitle,
              value: preferences.systemNotifications,
              onChanged: (v) =>
                  _update(ref, (p) => p.copyWith(systemNotifications: v)),
            ),
          ],
        ),
      ],
    );
  }
}

/// One preference group: an eyebrow over a hairline card of switches.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MadeenSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(title: title),
          const SizedBox(height: MadeenSpace.xs),
          MadeenCard(
            padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.md),
            child: MadeenDividedList(children: children),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: MadeenType.bodyMd.copyWith(
          color: t.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
      ),
      value: value,
      onChanged: onChanged,
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
      actionLabel: l10n.notificationPreferencesRetryButton,
      onAction: onRetry,
    );
  }
}
