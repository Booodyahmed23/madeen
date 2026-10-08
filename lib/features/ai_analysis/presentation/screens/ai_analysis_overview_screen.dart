import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../widgets/ai_summary_panel.dart';
import '../../domain/entities/ai_analysis.dart';
import '../../domain/entities/ai_analysis_scope.dart';
import '../providers/ai_analysis_providers.dart';
import '../widgets/ai_analysis_section.dart';
import '../widgets/ai_insight_tile.dart';
import '../widgets/ai_recommendation_tile.dart';
import '../widgets/ai_topic_insight_card.dart';

/// AI-Powered Performance Analysis over whatever attemptType scope
/// Performance Overview currently has selected (see this feature's README).
/// An *explanatory/recommendation* layer, never a source of truth: every
/// number reachable from here already exists on a Performance Analytics
/// screen — see [AiAnalysis]'s doc comment.
class AiAnalysisOverviewScreen extends ConsumerWidget {
  const AiAnalysisOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final analysisAsync = ref.watch(overallAiAnalysisProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiAnalysisTitle)),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isAiAnalysisApiAvailable,
            message: l10n.aiAnalysisSampleDataNotice,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(overallAiAnalysisProvider);
                await ref.read(overallAiAnalysisProvider.future);
              },
              child: analysisAsync.when(
                loading: () => const MadeenPageLoading(),
                error: (error, _) => _ErrorView(
                  error: error,
                  l10n: l10n,
                  onRetry: () async {
                    ref.invalidate(overallAiAnalysisProvider);
                    await ref.read(overallAiAnalysisProvider.future);
                  },
                ),
                data: (analysis) =>
                    _AnalysisBody(analysis: analysis, l10n: l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({required this.analysis, required this.l10n});

  final AiAnalysis analysis;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final metadata = analysis.metadata;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.md,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          l10n.aiAnalysisExplanation,
          style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: MadeenSpace.md),
        AiSummaryPanel(
          title: l10n.aiAnalysisOverallSummaryLabel,
          text: analysis.overallSummary,
        ),
        if (metadata.status == AiAnalysisStatus.ready) ...[
          const SizedBox(height: MadeenSpace.md),
          if (analysis.strengths.isNotEmpty)
            AiAnalysisSection(
              title: l10n.aiAnalysisStrengthsLabel,
              children: analysis.strengths
                  .map(
                    (s) => AiInsightTile(
                      insight: s,
                      kindLabel: l10n.aiAnalysisStrengthsLabel,
                    ),
                  )
                  .toList(),
            ),
          if (analysis.weaknesses.isNotEmpty)
            AiAnalysisSection(
              title: l10n.aiAnalysisWeaknessesLabel,
              children: analysis.weaknesses
                  .map(
                    (w) => AiInsightTile(
                      insight: w,
                      kindLabel: l10n.aiAnalysisWeaknessesLabel,
                    ),
                  )
                  .toList(),
            ),
          if (analysis.topicInsights.isNotEmpty)
            AiAnalysisSection(
              title: l10n.aiAnalysisTopicInsightsLabel,
              children: analysis.topicInsights
                  .map(
                    (t) => AiTopicInsightCard(
                      insight: t,
                      onTap: () => context.push(
                        AppRoutes.aiAnalysisTopic(t.topicId),
                        extra: t.topicName,
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (analysis.recurringPatterns.isNotEmpty)
            AiAnalysisSection(
              title: l10n.aiAnalysisRecurringPatternsLabel,
              children: analysis.recurringPatterns
                  .map(
                    (p) => AiInsightTile(
                      insight: p,
                      kindLabel: l10n.aiAnalysisRecurringPatternsLabel,
                    ),
                  )
                  .toList(),
            ),
          if (analysis.recommendations.isNotEmpty)
            AiAnalysisSection(
              title: l10n.aiAnalysisRecommendationsLabel,
              children: analysis.recommendations
                  .map(
                    (r) => AiRecommendationTile(
                      recommendation: r,
                      onTap: r.topicId == null
                          ? null
                          : () => context.push(
                              AppRoutes.aiAnalysisTopic(r.topicId!),
                              extra: r.topicName,
                            ),
                    ),
                  )
                  .toList(),
            ),
          if (metadata.basedOnAttemptCount != null) ...[
            Text(
              l10n.aiAnalysisBasedOnAttempts(metadata.basedOnAttemptCount!),
              style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
            ),
          ],
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.l10n,
    required this.onRetry,
  });

  final Object error;
  final AppLocalizations l10n;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? localizedFailureMessage(l10n, error as AppFailure)
        : l10n.aiAnalysisGenericError;

    return MadeenPageMessage(
      message: message,
      isError: true,
      actionLabel: l10n.performanceRetryButton,
      onAction: onRetry,
    );
  }
}
