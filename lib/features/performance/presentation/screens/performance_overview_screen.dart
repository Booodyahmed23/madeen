import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/v2_features.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../providers/performance_providers.dart';
import '../widgets/accuracy_ring.dart';
import '../widgets/attempt_summary_tile.dart';
import '../widgets/attempt_type_filter_bar.dart';
import '../widgets/performance_format.dart';
import '../widgets/topic_performance_tile.dart';

/// High-level Performance summary: overall accuracy/score, a few headline
/// stats, then previews of Topic Performance and Recent Attempts with links
/// to their own dedicated screens. Deliberately kept to one screen's worth
/// of scrolling — the full lists live on their own screens (Home →
/// Performance → Topic Performance / Attempt History).
class PerformanceOverviewScreen extends ConsumerWidget {
  const PerformanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overviewAsync = ref.watch(performanceOverviewProvider);
    final topicsAsync = ref.watch(topicPerformanceProvider);
    final attemptsAsync = ref.watch(recentAttemptsPreviewProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.performanceOverviewTitle)),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isPerformanceApiAvailable,
            message: l10n.performanceSampleDataNotice,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(performanceOverviewProvider);
                ref.invalidate(topicPerformanceProvider);
                await ref.read(performanceOverviewProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MadeenSpace.pageMargin,
                  MadeenSpace.md,
                  MadeenSpace.pageMargin,
                  MadeenSpace.xl,
                ),
                children: [
                  const AttemptTypeFilterBar(),
                  const SizedBox(height: MadeenSpace.md),
                  if (ref.watch(v2FeaturesProvider).aiAnalysis) ...[
                    _AiAnalysisEntryCard(
                      onTap: () => context.push(AppRoutes.aiAnalysisOverview),
                    ),
                    const SizedBox(height: MadeenSpace.md),
                  ],
                  ...overviewAsync.when(
                    loading: () => const [MadeenLoadingState()],
                    error: (error, _) => [
                      _ErrorView(
                        error: error,
                        onRetry: () async {
                          ref.invalidate(performanceOverviewProvider);
                          await ref.read(performanceOverviewProvider.future);
                        },
                      ),
                    ],
                    data: (overview) => overview.totalAttempts == 0
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: MadeenSpace.xxl,
                              ),
                              child: MadeenPageMessage(
                                message: l10n.performanceNoAttempts,
                              ),
                            ),
                          ]
                        : [
                            MadeenCard(
                              child: Column(
                                children: [
                                  // Rings scale down together rather than
                                  // overflowing on narrow screens.
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: AccuracyRing(
                                            percent:
                                                overview.overallAccuracyPercent,
                                            label: l10n
                                                .performanceOverallAccuracyLabel,
                                            semanticLabel:
                                                '${l10n.performanceOverallAccuracyLabel}: '
                                                '${overview.overallAccuracyPercent.round()}%',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: MadeenSpace.md),
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: AccuracyRing(
                                            percent:
                                                overview.overallScorePercent,
                                            label: l10n
                                                .performanceOverallScoreLabel,
                                            semanticLabel:
                                                '${l10n.performanceOverallScoreLabel}: '
                                                '${overview.overallScorePercent.round()}%',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: MadeenSpace.lg),
                                  MadeenPairGrid(
                                    children: [
                                      MadeenMetricTile(
                                        label: l10n
                                            .performanceQuestionsPracticedLabel,
                                        value: '${overview.questionsPracticed}',
                                      ),
                                      MadeenMetricTile(
                                        label: l10n.performanceTotalTimeLabel,
                                        value: formatPerformanceDuration(
                                          overview.totalTime,
                                        ),
                                      ),
                                      MadeenMetricTile(
                                        label: l10n.performanceAverageTimeLabel,
                                        value: formatPerformanceDuration(
                                          overview.averageTimePerQuestion,
                                        ),
                                      ),
                                      MadeenMetricTile(
                                        label: l10n.performanceCorrectLabel,
                                        value: '${overview.totalCorrect}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: MadeenSpace.md),
                            MadeenCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  MadeenSectionHeader(
                                    title:
                                        l10n.performanceTopicPerformanceLabel,
                                    trailing: TextButton(
                                      onPressed: () => context.push(
                                        AppRoutes.performanceTopics,
                                      ),
                                      child: Text(
                                        l10n.performanceAllTopicsButton,
                                      ),
                                    ),
                                  ),
                                  topicsAsync.when(
                                    loading: () => const MadeenLoadingState(),
                                    error: (_, _) => MadeenEmptyState(
                                      message: l10n.performanceGenericError,
                                    ),
                                    data: (topics) => topics.isEmpty
                                        ? MadeenEmptyState(
                                            message: l10n.performanceNoTopics,
                                          )
                                        : MadeenDividedList(
                                            children: [
                                              for (final topic in topics.take(
                                                3,
                                              ))
                                                TopicPerformanceTile(
                                                  topic: topic,
                                                ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: MadeenSpace.md),
                            MadeenCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  MadeenSectionHeader(
                                    title: l10n.performanceRecentAttemptsLabel,
                                    trailing: TextButton(
                                      onPressed: () => context.push(
                                        AppRoutes.performanceAttempts,
                                      ),
                                      child: Text(l10n.performanceSeeAllButton),
                                    ),
                                  ),
                                  attemptsAsync.when(
                                    loading: () => const MadeenLoadingState(),
                                    error: (_, _) => MadeenEmptyState(
                                      message: l10n.performanceGenericError,
                                    ),
                                    data: (attempts) => attempts.isEmpty
                                        ? MadeenEmptyState(
                                            message: l10n.performanceNoAttempts,
                                          )
                                        : MadeenDividedList(
                                            children: [
                                              for (final a in attempts)
                                                AttemptSummaryTile(
                                                  attempt: a,
                                                  onTap: () => context.push(
                                                    AppRoutes.performanceAttemptDetail(
                                                      a.attemptId,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry point into AI-Powered Performance Analysis (Phase 7) — this
/// feature only knows the route constant and its own two AI-Analysis-owned
/// l10n strings, never anything from `features/ai_analysis/` itself, so
/// Performance stays independent of that feature exactly the way it stays
/// independent of Study Session/Exam Simulation (see this feature's
/// README). Styled like Home's AI panel: the recessed, interpretive tone.
class _AiAnalysisEntryCard extends StatelessWidget {
  const _AiAnalysisEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);

    return MadeenCard(
      tone: MadeenCardTone.muted,
      onTap: onTap,
      semanticLabel:
          '${l10n.aiAnalysisEntryCardTitle}: ${l10n.aiAnalysisEntryCardSubtitle}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(
            title: l10n.aiAnalysisEntryCardTitle,
            icon: Icons.psychology_outlined,
            trailing: Icon(
              Icons.chevron_right,
              size: 20,
              color: t.inkSecondary,
            ),
          ),
          const SizedBox(height: MadeenSpace.xs),
          Text(
            l10n.aiAnalysisEntryCardSubtitle,
            style: MadeenType.bodyMd.copyWith(color: t.ink),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = error is AppFailure
        ? localizedFailureMessage(l10n, error as AppFailure)
        : l10n.performanceGenericError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MadeenSpace.xl),
      child: MadeenPageMessage(
        message: message,
        isError: true,
        actionLabel: l10n.performanceRetryButton,
        onAction: onRetry,
      ),
    );
  }
}
