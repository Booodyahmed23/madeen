import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/performance/presentation/providers/performance_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/madeen/madeen.dart';

/// Home's Performance Snapshot — a thin dashboard-sized view over
/// [performanceOverviewProvider], the exact same provider (and therefore
/// the exact same numbers) `PerformanceOverviewScreen` itself reads. Never a
/// second fetch of the same data under a different shape.
///
/// Presented as the reference design's telemetry group: a section eyebrow
/// with a "See Performance" link, and four tabular metric tiles (accuracy —
/// the headline figure — in the brand accent).
class PerformanceSnapshotCard extends ConsumerWidget {
  const PerformanceSnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overviewAsync = ref.watch(performanceOverviewProvider);

    return MadeenCard(
      onTap: () => context.push(AppRoutes.performanceOverview),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(
            title: l10n.homePerformanceSnapshotTitle,
            trailing: MadeenHeaderLink(label: l10n.homeSeePerformance),
          ),
          const SizedBox(height: MadeenSpace.md),
          overviewAsync.when(
            loading: () => const MadeenLoadingState(),
            error: (error, _) => MadeenErrorState(
              message: l10n.performanceGenericError,
              retryLabel: l10n.performanceRetryButton,
              onRetry: () => ref.invalidate(performanceOverviewProvider),
            ),
            data: (overview) => MadeenPairGrid(
              children: [
                MadeenMetricTile(
                  value: '${overview.overallAccuracyPercent.round()}%',
                  label: l10n.performanceOverallAccuracyLabel,
                  emphasize: true,
                ),
                MadeenMetricTile(
                  value: '${overview.overallScorePercent.round()}%',
                  label: l10n.performanceOverallScoreLabel,
                ),
                MadeenMetricTile(
                  value: '${overview.questionsPracticed}',
                  label: l10n.performanceQuestionsPracticedLabel,
                ),
                MadeenMetricTile(
                  value: '${overview.totalAttempts}',
                  label: l10n.homeTotalAttemptsLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
