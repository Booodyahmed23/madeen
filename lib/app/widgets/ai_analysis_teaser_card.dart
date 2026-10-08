import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/ai_analysis/presentation/providers/ai_analysis_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/madeen/madeen.dart';

/// Home's AI Analysis teaser — the exact same [overallAiAnalysisProvider]
/// AI Analysis Overview itself reads. [AiAnalysis.overallSummary] is shown
/// verbatim: per that field's own doc comment, it already **is** the
/// honest "complete more study activity..." explanation when
/// [AiAnalysisStatus.insufficientData], so this card never needs a second,
/// Home-only copy of that message — doing so would risk it drifting out of
/// sync with what the AI Analysis screen itself says.
///
/// Presented as the reference's recessed "diagnostic" panel: a quieter
/// muted tone that sets the interpretive AI layer apart from the factual
/// metrics above it.
class AiAnalysisTeaserCard extends ConsumerWidget {
  const AiAnalysisTeaserCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final analysisAsync = ref.watch(overallAiAnalysisProvider);

    return MadeenCard(
      tone: MadeenCardTone.muted,
      onTap: () => context.push(AppRoutes.aiAnalysisOverview),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(
            title: l10n.aiAnalysisTitle,
            icon: Icons.psychology_outlined,
            trailing: Icon(
              Icons.chevron_right,
              size: 20,
              color: t.inkSecondary,
            ),
          ),
          const SizedBox(height: MadeenSpace.sm),
          analysisAsync.when(
            loading: () => const MadeenLoadingState(),
            error: (error, _) => MadeenErrorState(
              message: l10n.aiAnalysisGenericError,
              retryLabel: l10n.performanceRetryButton,
              onRetry: () => ref.invalidate(overallAiAnalysisProvider),
            ),
            data: (analysis) => Text(
              analysis.overallSummary,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}
