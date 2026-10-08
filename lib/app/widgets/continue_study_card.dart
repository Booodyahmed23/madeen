import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure_messages.dart';
import '../../core/router/app_router.dart';
import '../../features/curriculum/presentation/providers/curriculum_providers.dart';
import '../../features/study_session/domain/entities/study_session.dart';
import '../../features/study_session/presentation/providers/study_session_notifier.dart';
import '../../features/study_session/presentation/providers/study_session_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/madeen/madeen.dart';

/// "Continue studying": the newest study session the student left
/// unfinished (contract §A8 B4). Shows nothing when there is none, or while
/// the list loads or can't be loaded — it's a shortcut, not a page.
class ContinueStudyCard extends ConsumerWidget {
  const ContinueStudyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(unfinishedStudySessionsProvider).value;
    if (sessions == null || sessions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.md),
      child: _Card(session: sessions.first),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.session});

  final StudySessionSummary session;

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(studySessionNotifierProvider.notifier);
    await notifier.reopenSession(session.id);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (ref.read(studySessionNotifierProvider)) {
      case StudySessionActive():
        context.push(AppRoutes.studySessionActive);
      case StudySessionCompleted():
        context.push(AppRoutes.studySessionResults);
      case StudySessionError(:final failure):
        notifier.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedFailureMessage(l10n, failure))),
        );
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final topicName = session.topicIds.isEmpty
        ? null
        : ref.watch(topicNameProvider(session.topicIds.first)).value;
    final isLoading =
        ref.watch(studySessionNotifierProvider) is StudySessionLoading;

    return MadeenCard(
      child: Row(
        children: [
          Icon(Icons.play_circle_outline, color: t.accentText),
          const SizedBox(width: MadeenSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeContinueStudyTitle,
                  style: MadeenType.headlineSm.copyWith(color: t.ink),
                ),
                const SizedBox(height: MadeenSpace.xxs),
                Text(
                  l10n.homeContinueStudySubtitle(
                    session.requestedCount,
                    topicName ?? l10n.studySessionSetupTitle,
                  ),
                  style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: MadeenSpace.sm),
          FilledButton(
            onPressed: isLoading ? null : () => _continue(context, ref),
            child: Text(l10n.homeContinueStudyAction),
          ),
        ],
      ),
    );
  }
}
