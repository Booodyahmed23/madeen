import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/ai_analysis.dart';
import '../../domain/entities/ai_analysis_scope.dart';
import '../providers/ai_analysis_providers.dart';
import '../widgets/ai_summary_panel.dart';

/// AI analysis for exactly one topic — reached from Topic Performance's
/// "Analyze with AI" action. Structure matches the phase brief's example
/// exactly: factual metrics, then AI Insight / Why this matters /
/// Recommended Action, all three sourced from the one [AiTopicInsight] this
/// scope always returns exactly one of.
class TopicAiInsightScreen extends ConsumerWidget {
  const TopicAiInsightScreen({
    super.key,
    required this.topicId,
    this.topicName,
  });

  final String topicId;
  final String? topicName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final analysisAsync = ref.watch(topicAiAnalysisProvider(topicId));

    return Scaffold(
      appBar: AppBar(
        title: Text(topicName ?? l10n.aiAnalysisTopicInsightTitle),
      ),
      body: analysisAsync.when(
        loading: () => const MadeenPageLoading(),
        error: (error, _) => _ErrorView(
          error: error,
          l10n: l10n,
          onRetry: () async {
            ref.invalidate(topicAiAnalysisProvider(topicId));
            await ref.read(topicAiAnalysisProvider(topicId).future);
          },
        ),
        data: (analysis) => _TopicBody(analysis: analysis, l10n: l10n),
      ),
    );
  }
}

class _TopicBody extends StatelessWidget {
  const _TopicBody({required this.analysis, required this.l10n});

  final AiAnalysis analysis;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);

    if (analysis.metadata.status == AiAnalysisStatus.insufficientData ||
        analysis.topicInsights.isEmpty) {
      return MadeenPageMessage(
        message: analysis.overallSummary,
        icon: Icons.psychology_outlined,
      );
    }

    final insight = analysis.topicInsights.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        MadeenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MadeenSectionHeader(title: l10n.performanceTopicPerformanceLabel),
              const SizedBox(height: MadeenSpace.sm),
              MadeenPairGrid(
                children: [
                  MadeenMetricTile(
                    label: l10n.performanceAccuracyLabel,
                    value: '${insight.accuracyPercent.round()}%',
                    emphasize: true,
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceAnsweredLabel,
                    value: '${insight.answered}',
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceCorrectLabel,
                    value: '${insight.correct}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MadeenSpace.md),
        AiSummaryPanel(
          title: l10n.aiAnalysisAiInsightLabel,
          text: analysis.overallSummary,
        ),
        const SizedBox(height: MadeenSpace.md),
        MadeenCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MadeenSectionHeader(title: l10n.aiAnalysisWhyThisMattersLabel),
              const SizedBox(height: MadeenSpace.xs),
              Text(
                insight.interpretation,
                style: MadeenType.bodyMd.copyWith(color: t.ink),
              ),
              const SizedBox(height: MadeenSpace.lg),
              MadeenSectionHeader(title: l10n.aiAnalysisRecommendedActionLabel),
              const SizedBox(height: MadeenSpace.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right_alt, size: 18, color: t.accentText),
                  const SizedBox(width: MadeenSpace.xs),
                  Expanded(
                    child: Text(
                      insight.recommendedAction,
                      style: MadeenType.bodyMd.copyWith(color: t.ink),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
