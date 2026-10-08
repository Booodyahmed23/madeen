import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/performance/domain/entities/attempt_summary.dart';
import '../../features/performance/domain/entities/attempt_type.dart';
import '../../features/performance/presentation/providers/performance_providers.dart';
import '../../features/performance/presentation/widgets/performance_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/madeen/madeen.dart';

/// Home's Recent Activity — up to three most recent attempts, the exact
/// same [recentAttemptsPreviewProvider] `PerformanceOverviewScreen` already
/// uses for its own preview. Each row opens Attempt Details — this is a
/// *view of what already happened*, never a claim that a Study Session can
/// be resumed (there is no persisted/resumable session across app restarts).
///
/// Rows use Home's own MADEEN [MadeenListRow] rather than Performance's
/// `AttemptSummaryTile`, so restyling Home never changes the Performance
/// screen; the row content and formatting (date, type label, question
/// count, score) are identical to that tile's.
class RecentActivitySection extends ConsumerWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final attemptsAsync = ref.watch(recentAttemptsPreviewProvider);

    return MadeenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(title: l10n.homeRecentActivityTitle),
          const SizedBox(height: MadeenSpace.xs),
          attemptsAsync.when(
            loading: () => const MadeenLoadingState(),
            error: (error, _) => MadeenErrorState(
              message: l10n.performanceGenericError,
              retryLabel: l10n.performanceRetryButton,
              onRetry: () => ref.invalidate(recentAttemptsPreviewProvider),
            ),
            data: (attempts) {
              if (attempts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: MadeenSpace.xs),
                  child: MadeenEmptyState(
                    message: l10n.homeRecentActivityEmpty,
                  ),
                );
              }
              return MadeenDividedList(
                children: [
                  for (final attempt in attempts)
                    _ActivityRow(attempt: attempt),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.attempt});

  final AttemptSummary attempt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isStudySession = attempt.type == AttemptType.studySession;
    final typeLabel = isStudySession
        ? l10n.performanceStudySessionLabel
        : l10n.performanceExamSimulationLabel;
    final dateLabel = formatPerformanceDate(context, attempt.completedAt);
    final questionsLabel = l10n.performanceAttemptQuestionsCount(
      attempt.totalQuestions,
    );
    final scoreLabel = '${attempt.scorePercent.round()}%';

    return MadeenListRow(
      icon: isStudySession ? Icons.menu_book_outlined : Icons.timer_outlined,
      title: attempt.contentLabel.isEmpty ? typeLabel : attempt.contentLabel,
      subtitle: '$dateLabel · $typeLabel · $questionsLabel',
      trailingValue: scoreLabel,
      semanticLabel:
          '$dateLabel, $typeLabel, ${attempt.contentLabel}, '
          '$questionsLabel, ${l10n.performanceScoreLabel} $scoreLabel',
      onTap: () =>
          context.push(AppRoutes.performanceAttemptDetail(attempt.attemptId)),
    );
  }
}
