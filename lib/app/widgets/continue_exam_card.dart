import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure_messages.dart';
import '../../core/router/app_router.dart';
import '../../features/exam_simulation/domain/entities/exam_attempt.dart';
import '../../features/exam_simulation/presentation/providers/exam_notifier.dart';
import '../../features/exam_simulation/presentation/providers/exam_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/madeen/madeen.dart';

/// "Continue your exam": the newest exam attempt whose time hasn't run out
/// (contract §A8 B4). Hidden when there is none, while loading, or on
/// error — and while an exam is already open in the app.
class ContinueExamCard extends ConsumerWidget {
  const ContinueExamCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(examNotifierProvider) is ExamActive) {
      return const SizedBox.shrink();
    }
    final attempts = ref.watch(unfinishedExamAttemptsProvider).value;
    if (attempts == null || attempts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.md),
      child: _Card(attempt: attempts.first),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.attempt});

  final ExamAttemptSummary attempt;

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(examNotifierProvider.notifier);
    await notifier.reopenAttempt(attempt.id);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (ref.read(examNotifierProvider)) {
      case ExamActive():
        context.push(AppRoutes.examActive);
      case ExamCompleted():
        context.push(AppRoutes.examResults);
      case ExamError(:final failure):
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
    final now = ref.watch(examClockProvider)().toUtc();
    final minutesLeft = (attempt.expiresAt.difference(now).inSeconds / 60)
        .ceil()
        .clamp(0, attempt.durationMinutes);
    final isLoading = ref.watch(examNotifierProvider) is ExamLoading;

    return MadeenCard(
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: t.accentText),
          const SizedBox(width: MadeenSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeContinueExamTitle,
                  style: MadeenType.headlineSm.copyWith(color: t.ink),
                ),
                const SizedBox(height: MadeenSpace.xxs),
                Text(
                  l10n.homeContinueExamSubtitle(
                    attempt.requestedCount,
                    minutesLeft,
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
