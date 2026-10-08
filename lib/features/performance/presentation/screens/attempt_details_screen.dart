import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../core/error/failure_messages.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/attempt_details.dart';
import '../../domain/entities/attempt_type.dart';
import '../providers/performance_providers.dart';
import '../widgets/performance_format.dart';
import '../widgets/topic_performance_tile.dart';

/// Full detail for one attempt — every field required by this phase's
/// brief, plus a topic breakdown when the backend has one (Study Session
/// attempts only; see [AttemptDetails.topics]'s doc comment) and a link
/// into that attempt type's own existing review screen.
///
/// That review link reuses Study Session's / Exam Simulation's existing
/// routes/screens exactly (never a duplicated review UI here — see this
/// feature's README), but those screens are driven by *their own* live
/// notifier state, not by an arbitrary historical `attemptId` — there is no
/// persistence layer yet that lets either feature reload an old attempt by
/// id (see STUDY_SESSION_API_REQUIREMENTS.md / EXAM_SIMULATION_API_
/// REQUIREMENTS.md's own "not yet wired" notes on `getAttempt`/session
/// resume). The button is therefore most useful right after finishing a
/// session/exam and drilling into its own fresh detail; for older history
/// entries it navigates to the same screen, which gracefully shows its own
/// "nothing to review" state rather than stale or wrong data — see
/// PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md's "Known limitations".
class AttemptDetailsScreen extends ConsumerWidget {
  const AttemptDetailsScreen({super.key, required this.attemptId});

  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailsAsync = ref.watch(attemptDetailsProvider(attemptId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.performanceAttemptDetailsTitle)),
      body: detailsAsync.when(
        loading: () => const MadeenPageLoading(),
        error: (error, _) => _ErrorView(
          error: error,
          l10n: l10n,
          onRetry: () async {
            ref.invalidate(attemptDetailsProvider(attemptId));
            await ref.read(attemptDetailsProvider(attemptId).future);
          },
        ),
        data: (details) => _DetailsBody(details: details, l10n: l10n),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.details, required this.l10n});

  final AttemptDetails details;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final summary = details.summary;
    final isStudySession = summary.type == AttemptType.studySession;
    final typeLabel = isStudySession
        ? l10n.performanceStudySessionLabel
        : l10n.performanceExamSimulationLabel;
    final dateLabel = formatPerformanceDate(context, summary.completedAt);

    final t = MadeenTokens.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        Text(
          summary.contentLabel,
          style: Theme.of(context).textTheme.headlineLarge!
              .copyWith(color: t.ink),
        ),
        const SizedBox(height: MadeenSpace.xxs),
        Text(
          '$typeLabel · $dateLabel',
          style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: MadeenSpace.lg),
        MadeenCard(
          child: Column(
            children: [
              MadeenScoreDisplay(
                label: l10n.performanceScoreLabel,
                value: '${summary.scorePercent.round()}%',
              ),
              const SizedBox(height: MadeenSpace.lg),
              MadeenPairGrid(
                children: [
                  MadeenMetricTile(
                    label: l10n.performanceQuestionsLabel,
                    value: '${summary.totalQuestions}',
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceAnsweredLabel,
                    value: '${summary.answered}',
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceUnansweredLabel,
                    value: '${details.unanswered}',
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceCorrectLabel,
                    value: '${summary.correct}',
                    valueColor: t.success,
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceWrongLabel,
                    value: '${details.wrong}',
                    valueColor: t.error,
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceAccuracyLabel,
                    value: '${summary.accuracyPercent.round()}%',
                    emphasize: true,
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceTotalTimeLabel,
                    value: formatPerformanceDuration(summary.duration),
                  ),
                  MadeenMetricTile(
                    label: l10n.performanceAverageTimeLabel,
                    value: formatPerformanceDuration(
                      details.averageTimePerQuestion,
                    ),
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
              MadeenSectionHeader(title: l10n.performanceTopicBreakdownLabel),
              const SizedBox(height: MadeenSpace.xs),
              if (details.topics.isEmpty)
                MadeenEmptyState(message: l10n.performanceNoTopicBreakdown)
              else
                MadeenDividedList(
                  children: [
                    for (final topic in details.topics)
                      TopicPerformanceTile(topic: topic),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: MadeenSpace.lg),
        MadeenPrimaryButton(
          label: l10n.aiAnalysisAnalyzeWithAiButton,
          icon: Icons.psychology_outlined,
          onPressed: () =>
              context.push(AppRoutes.aiAnalysisAttempt(summary.attemptId)),
        ),
        const SizedBox(height: MadeenSpace.sm),
        SizedBox(
          width: double.infinity,
          child: MadeenSecondaryButton(
            label: l10n.performanceReviewAnswersButton,
            onPressed: () => context.push(
              isStudySession
                  ? AppRoutes.studySessionReview
                  : AppRoutes.examPostReview,
            ),
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
        : l10n.performanceGenericError;

    return MadeenPageMessage(
      message: message,
      isError: true,
      actionLabel: l10n.performanceRetryButton,
      onAction: onRetry,
    );
  }
}
