import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/ai_analysis.dart';
import '../providers/ai_analysis_providers.dart';
import '../widgets/ai_analysis_section.dart';
import '../widgets/ai_insight_tile.dart';
import '../widgets/ai_recommendation_tile.dart';
import '../widgets/ai_summary_panel.dart';
import '../widgets/ai_topic_insight_card.dart';

/// AI analysis for exactly one completed attempt — reached from Attempt
/// Details' "Analyze with AI" action. Never diagnoses *why* a mistake
/// happened (the brief's explicit "AI principles"); [analysis.
/// recurringPatterns] only ever states an observation this attempt's own
/// data supports (e.g. pace vs. typical, count of wrong answers).
class AttemptAiInsightScreen extends ConsumerWidget {
  const AttemptAiInsightScreen({super.key, required this.attemptId});

  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final analysisAsync = ref.watch(attemptAiAnalysisProvider(attemptId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiAnalysisAttemptInsightTitle)),
      body: analysisAsync.when(
        loading: () => const MadeenPageLoading(),
        error: (error, _) => _ErrorView(
          error: error,
          l10n: l10n,
          onRetry: () async {
            ref.invalidate(attemptAiAnalysisProvider(attemptId));
            await ref.read(attemptAiAnalysisProvider(attemptId).future);
          },
        ),
        data: (analysis) => _AttemptBody(analysis: analysis, l10n: l10n),
      ),
    );
  }
}

class _AttemptBody extends StatelessWidget {
  const _AttemptBody({required this.analysis, required this.l10n});

  final AiAnalysis analysis;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        AiSummaryPanel(
          title: l10n.aiAnalysisAiInsightLabel,
          text: analysis.overallSummary,
        ),
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
                .map((t) => AiTopicInsightCard(insight: t))
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
                .map((r) => AiRecommendationTile(recommendation: r))
                .toList(),
          ),
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
