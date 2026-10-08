import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/study_session_notifier.dart';
import '../providers/study_session_state.dart';
import '../widgets/session_timer_display.dart';

/// Shows the authoritative [SessionResult] — every number here comes
/// straight from the repository response, never recomputed locally (see
/// ARCHITECTURE.md: "do not calculate metrics differently from the backend
/// if authoritative results are provided").
class StudySessionResultsScreen extends ConsumerWidget {
  const StudySessionResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(studySessionNotifierProvider);

    if (state is! StudySessionCompleted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studySessionResultsTitle)),
        body: Center(child: Text(l10n.studySessionGenericError)),
      );
    }

    final result = state.result;
    final t = MadeenTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.config.topicName),
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
                  MadeenScoreDisplay(
                    label: l10n.studySessionResultsScoreLabel,
                    value: '${result.scorePercent.round()}%',
                  ),
                  const SizedBox(height: MadeenSpace.lg),
                  MadeenPairGrid(
                    children: [
                      MadeenMetricTile(
                        label: l10n.studySessionResultsQuestionsLabel,
                        value: '${result.totalQuestions}',
                      ),
                      MadeenMetricTile(
                        label: l10n.studySessionResultsAnsweredLabel,
                        value: '${result.answered}',
                      ),
                      MadeenMetricTile(
                        label: l10n.studySessionResultsCorrectLabel,
                        value: '${result.correct}',
                        valueColor: t.success,
                      ),
                      MadeenMetricTile(
                        label: l10n.studySessionResultsIncorrectLabel,
                        value: '${result.incorrect}',
                        valueColor: t.error,
                      ),
                      MadeenMetricTile(
                        label: l10n.studySessionResultsUnansweredLabel,
                        value: '${result.unanswered}',
                      ),
                      MadeenMetricTile(
                        label: l10n.studySessionResultsTotalTimeLabel,
                        value: SessionTimerDisplay.format(result.totalTime),
                      ),
                      MadeenMetricTile(
                        label: l10n.studySessionResultsAverageTimeLabel,
                        value: SessionTimerDisplay.format(
                          result.averageTimePerQuestion,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MadeenSpace.lg),
            SizedBox(
              width: double.infinity,
              child: MadeenSecondaryButton(
                label: l10n.studySessionResultsReviewButton,
                onPressed: () => context.push(AppRoutes.studySessionReview),
              ),
            ),
            const SizedBox(height: MadeenSpace.sm),
            SizedBox(
              width: double.infinity,
              height: MadeenSize.buttonHeight,
              child: FilledButton(
                onPressed: () {
                  ref.read(studySessionNotifierProvider.notifier).reset();
                  // Home, like Exam Results' Done: it now reflects this
                  // attempt (Performance Snapshot, Recent Activity). `go` to
                  // the top-level /curriculum used to replace the whole stack,
                  // leaving the student with no way back to Home.
                  context.go(AppRoutes.home);
                },
                child: Text(l10n.studySessionResultsDoneButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
