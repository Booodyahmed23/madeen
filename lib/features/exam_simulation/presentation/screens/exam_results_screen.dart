import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/exam_review_item.dart';
import '../../domain/entities/exam_topic_breakdown.dart';
import '../providers/exam_notifier.dart';
import '../providers/exam_state.dart';
import '../widgets/exam_question_grid.dart';
import 'exam_post_review_screen.dart';

/// Shows the authoritative [ExamResult] — every score/count here comes
/// straight from the repository response, never recomputed locally. The
/// per-topic breakdown and the wrong/unanswered lists only *group* the
/// authoritative post-submission review items (see [examTopicBreakdown]).
class ExamResultsScreen extends ConsumerWidget {
  const ExamResultsScreen({super.key});

  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
    'completed' => l10n.examCompletionStatusCompleted,
    'timed_out' => l10n.examCompletionStatusTimedOut,
    // An unrecognized future value from the backend — show it verbatim
    // rather than silently mapping to the wrong label.
    _ => status,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(examNotifierProvider);

    if (state is! ExamCompleted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.examResultsTitle)),
        body: Center(child: Text(l10n.examGenericError)),
      );
    }

    final result = state.result;
    final t = MadeenTokens.of(context);
    final review = state.review;
    final topics = examTopicBreakdown(review);
    final averagePerQuestion = result.totalQuestions == 0
        ? Duration.zero
        : Duration(
            seconds: result.durationTaken.inSeconds ~/ result.totalQuestions,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.examResultsTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MadeenSpace.pageMargin,
            MadeenSpace.lg,
            MadeenSpace.pageMargin,
            MadeenSpace.xl,
          ),
          children: [
            MadeenCard(
              child: Column(
                children: [
                  MadeenSectionHeader(title: l10n.examResultsOverallTitle),
                  const SizedBox(height: MadeenSpace.sm),
                  MadeenScoreDisplay(
                    label: l10n.examResultsScoreLabel,
                    value: '${result.scorePercent.round()}%',
                  ),
                  const SizedBox(height: MadeenSpace.lg),
                  MadeenPairGrid(
                    children: [
                      MadeenMetricTile(
                        label: l10n.examResultsQuestionsLabel,
                        value: '${result.totalQuestions}',
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsAnsweredLabel,
                        value: '${result.answered}',
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsCorrectLabel,
                        value: '${result.correct}',
                        valueColor: t.success,
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsIncorrectLabel,
                        value: '${result.incorrect}',
                        valueColor: t.error,
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsUnansweredLabel,
                        value: '${result.unanswered}',
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsDurationLabel,
                        value: _formatDuration(result.durationTaken),
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsAverageTimeLabel,
                        value: _formatDuration(averagePerQuestion),
                      ),
                      MadeenMetricTile(
                        label: l10n.examResultsStatusLabel,
                        value: _statusLabel(l10n, result.completionStatus),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (topics.isNotEmpty) ...[
              const SizedBox(height: MadeenSpace.md),
              _TopicBreakdownCard(topics: topics),
            ],
            if (review.isNotEmpty) ...[
              const SizedBox(height: MadeenSpace.md),
              _QuestionListCard(
                title: l10n.examResultsWrongQuestionsTitle,
                emptyMessage: l10n.examResultsNoneWrong,
                review: review,
                view: ExamReviewView.wrong,
              ),
              const SizedBox(height: MadeenSpace.md),
              _QuestionListCard(
                title: l10n.examResultsUnansweredQuestionsTitle,
                emptyMessage: l10n.examResultsNoneUnanswered,
                review: review,
                view: ExamReviewView.unanswered,
              ),
            ],
            const SizedBox(height: MadeenSpace.lg),
            SizedBox(
              width: double.infinity,
              child: MadeenSecondaryButton(
                label: l10n.examResultsReviewButton,
                onPressed: () => context.push(AppRoutes.examPostReview),
              ),
            ),
            const SizedBox(height: MadeenSpace.sm),
            SizedBox(
              width: double.infinity,
              height: MadeenSize.buttonHeight,
              child: FilledButton(
                onPressed: () {
                  ref.read(examNotifierProvider.notifier).reset();
                  context.go(AppRoutes.home);
                },
                child: Text(l10n.examResultsDoneButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// One row per topic: name, "x of y correct", score and a pacing bar.
class _TopicBreakdownCard extends StatelessWidget {
  const _TopicBreakdownCard({required this.topics});

  final List<ExamTopicBreakdown> topics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return MadeenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(title: l10n.examResultsByTopicTitle),
          const SizedBox(height: MadeenSpace.xs),
          MadeenDividedList(
            children: [
              for (final topic in topics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MadeenSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topic.topicName,
                              style: MadeenType.bodyMd.copyWith(
                                color: t.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: MadeenSpace.sm),
                          Text(
                            '${topic.scorePercent.round()}%',
                            style: MadeenType.metricMd.copyWith(color: t.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: MadeenSpace.xxs),
                      Text(
                        l10n.examResultsTopicScore(topic.correct, topic.total),
                        style: MadeenType.bodySm.copyWith(
                          color: t.inkSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: MadeenSpace.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          MadeenRadius.base / 2,
                        ),
                        child: LinearProgressIndicator(
                          value: topic.scorePercent / 100,
                          minHeight: 3,
                          backgroundColor: t.hairline,
                          color: t.accent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The wrong (or unanswered) questions as numbered cells — each opens the
/// post-exam review on that view, scrolled to that question.
class _QuestionListCard extends StatelessWidget {
  const _QuestionListCard({
    required this.title,
    required this.emptyMessage,
    required this.review,
    required this.view,
  });

  final String title;
  final String emptyMessage;
  final List<ExamReviewItem> review;
  final ExamReviewView view;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final matches = [
      for (var i = 0; i < review.length; i++)
        if (view.includes(review[i])) (number: i + 1, item: review[i]),
    ];

    return MadeenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(
            title: title,
            trailing: Text(
              '${matches.length}',
              style: MadeenType.labelMd.copyWith(
                color: t.inkSecondary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: MadeenSpace.sm),
          if (matches.isEmpty)
            Text(
              emptyMessage,
              style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
            )
          else
            ExamQuestionGrid(
              count: matches.length,
              numberFor: (i) => matches[i].number,
              stateFor: (i) => ExamQuestionCellState(
                isAnswered: !matches[i].item.isUnanswered,
              ),
              onSelected: (i) => context.push(
                AppRoutes.examPostReviewAt(
                  show: view.toQuery(),
                  questionId: matches[i].item.questionId,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
