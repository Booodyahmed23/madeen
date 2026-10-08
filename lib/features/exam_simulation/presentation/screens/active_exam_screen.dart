import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../core/error/failure_messages.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/exam_notifier.dart';
import '../providers/exam_state.dart';
import '../widgets/exam_answer_choice_tile.dart';
import '../widgets/exam_countdown_display.dart';
import '../widgets/exam_progress_bar.dart';
import '../widgets/exam_question_grid.dart';
import '../widgets/exam_submit_confirmation.dart';

/// What the student chose in the question navigator sheet.
sealed class _NavigatorAction {
  const _NavigatorAction();
}

class _GoTo extends _NavigatorAction {
  const _GoTo(this.index);
  final int index;
}

class _OpenReview extends _NavigatorAction {
  const _OpenReview();
}

class _Submit extends _NavigatorAction {
  const _Submit();
}

/// The exam-mode question-answering loop. Deliberately does **not** show:
/// - any topic/program/part label in the question chrome (only "Exam" —
///   see `l10n.examActiveTitle`)
/// - any correctness feedback, ever (no submit-per-question call exists in
///   this feature at all — see ExamNotifier's doc comment)
/// - a pause control (no such method exists on ExamNotifier to call)
///
/// The question navigator (a bottom sheet) shows every question's
/// answered/unanswered/flagged state and the current position, and is one
/// of the two ways to submit — the other being the Exam Review screen.
class ActiveExamScreen extends ConsumerWidget {
  const ActiveExamScreen({super.key});

  Future<void> _openNavigator(
    BuildContext context,
    ExamNotifier notifier,
  ) async {
    final action = await showModalBottomSheet<_NavigatorAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QuestionNavigatorSheet(),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _GoTo(:final index):
        notifier.goToQuestion(index);
      case _OpenReview():
        context.push(AppRoutes.examSubmissionReview);
      case _Submit():
        // Re-read: the clock kept running while the sheet was open.
        final current = notifier.currentActive;
        if (current == null) return;
        if (await confirmExamSubmission(
          context,
          unansweredCount: current.unansweredCount,
        )) {
          await notifier.submitExam();
        }
    }
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.examLeaveExamTitle),
        content: Text(l10n.examLeaveExamMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.examLeaveExamCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.examLeaveExamConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(examNotifierProvider);
    final notifier = ref.read(examNotifierProvider.notifier);

    ref.listen<ExamState>(examNotifierProvider, (previous, next) {
      if (next is ExamCompleted) {
        context.pushReplacement(AppRoutes.examResults);
      }
    });

    // Timeout and the submission it triggers keep this same screen mounted
    // (an overlay takes over) rather than navigating away immediately —
    // the student should see *why* the exam ended before landing on
    // Results.
    final overlayActive = switch (state) {
      ExamActive s => s,
      ExamTimedOut s => s.active,
      ExamSubmitting s => s.active,
      ExamError(:final retryFrom?) => retryFrom,
      _ => null,
    };

    if (overlayActive == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.examActiveTitle)),
        body: Center(child: Text(l10n.examGenericError)),
      );
    }

    final question = overlayActive.currentQuestion;
    final selectedChoiceId = overlayActive.selectedChoiceForCurrent;
    final isFlagged = overlayActive.isCurrentFlagged;
    final isOverlayShown =
        state is ExamTimedOut || state is ExamSubmitting || state is ExamError;
    final isInteractive = state is ExamActive;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!isInteractive) return; // can't back out of a finishing exam
        if (await _confirmLeave(context)) {
          notifier.reset();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.examActiveTitle),
          automaticallyImplyLeading: isInteractive,
          actions: [
            IconButton(
              tooltip: isFlagged ? l10n.examUnflagButton : l10n.examFlagButton,
              icon: Icon(isFlagged ? Icons.flag : Icons.outlined_flag),
              // DESIGN.md "Flagged State": terracotta attention.
              color: isFlagged ? MadeenTokens.of(context).attention : null,
              onPressed: isInteractive ? notifier.toggleFlag : null,
            ),
            IconButton(
              tooltip: l10n.examNavigatorButton,
              icon: const Icon(Icons.grid_view_outlined),
              onPressed: isInteractive
                  ? () => _openNavigator(context, notifier)
                  : null,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MadeenSpace.pageMargin,
                      MadeenSpace.sm,
                      MadeenSpace.pageMargin,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ExamProgressBar(
                            current: overlayActive.currentIndex + 1,
                            total: overlayActive.totalQuestions,
                          ),
                        ),
                        const SizedBox(width: MadeenSpace.md),
                        ExamCountdownDisplay(
                          remaining: Duration(
                            seconds: overlayActive.remainingSeconds,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AnsweredStatusLine(
                    active: overlayActive,
                    onTap: isInteractive
                        ? () => _openNavigator(context, notifier)
                        : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        MadeenSpace.pageMargin,
                        MadeenSpace.lg,
                        MadeenSpace.pageMargin,
                        MadeenSpace.lg,
                      ),
                      children: [
                        MadeenContentText(
                          question.text,
                          style: MadeenType.question.copyWith(
                            color: MadeenTokens.of(context).ink,
                          ),
                        ),
                        const SizedBox(height: MadeenSpace.lg),
                        // DESIGN.md: answer clusters keep a fixed 12px gap.
                        for (final choice in question.choices)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: MadeenSpace.sm,
                            ),
                            child: ExamAnswerChoiceTile(
                              choice: choice,
                              isSelected: choice.id == selectedChoiceId,
                              onTap: isInteractive
                                  ? () => notifier.selectChoice(choice.id)
                                  : () {},
                            ),
                          ),
                      ],
                    ),
                  ),
                  _BottomBar(
                    active: overlayActive,
                    notifier: notifier,
                    enabled: isInteractive,
                  ),
                ],
              ),
              if (isOverlayShown)
                _TimeoutOverlay(state: state, notifier: notifier),
            ],
          ),
        ),
      ),
    );
  }
}

/// "5 of 20 answered · 2 flagged" — always visible, and a shortcut into
/// the question navigator.
class _AnsweredStatusLine extends StatelessWidget {
  const _AnsweredStatusLine({required this.active, required this.onTap});

  final ExamActive active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final style = MadeenType.bodySm.copyWith(
      color: t.inkSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MadeenSpace.pageMargin,
          vertical: MadeenSpace.xs,
        ),
        child: Row(
          children: [
            Icon(Icons.grid_view_outlined, size: 16, color: t.inkSecondary),
            const SizedBox(width: MadeenSpace.xs),
            Flexible(
              child: Text(
                l10n.examAnsweredProgress(
                  active.answeredCount,
                  active.totalQuestions,
                ),
                style: style,
              ),
            ),
            if (active.flaggedCount > 0) ...[
              const SizedBox(width: MadeenSpace.sm),
              Icon(Icons.flag, size: 14, color: t.attention),
              const SizedBox(width: MadeenSpace.xxs),
              Text(
                l10n.examFlaggedCount(active.flaggedCount),
                style: style.copyWith(color: t.attention),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The question navigator: every question as a numbered cell, a legend,
/// and the ways out — Review (the full pre-submission screen) or Submit.
/// Reads the live exam state itself, so the counts stay current while the
/// countdown keeps running underneath.
class _QuestionNavigatorSheet extends ConsumerWidget {
  const _QuestionNavigatorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final state = ref.watch(examNotifierProvider);
    // The exam can end (timeout) while the sheet is open — close it so the
    // timeout overlay underneath is visible.
    if (state is! ExamActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    final active = state;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MadeenSpace.pageMargin,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.examNavigatorTitle,
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(color: t.ink),
                    ),
                  ),
                  ExamCountdownDisplay(
                    remaining: Duration(seconds: active.remainingSeconds),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MadeenSpace.pageMargin,
                MadeenSpace.xxs,
                MadeenSpace.pageMargin,
                MadeenSpace.md,
              ),
              child: Text(
                l10n.examAnsweredProgress(
                  active.answeredCount,
                  active.totalQuestions,
                ),
                style: MadeenType.bodySm.copyWith(
                  color: t.inkSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MadeenSpace.pageMargin,
                ),
                child: ExamQuestionGrid(
                  count: active.totalQuestions,
                  stateFor: (i) {
                    final id = active.questions[i].id;
                    return ExamQuestionCellState(
                      isAnswered: active.selectedAnswers.containsKey(id),
                      isCurrent: i == active.currentIndex,
                      isFlagged: active.flaggedQuestionIds.contains(id),
                    );
                  },
                  onSelected: (i) => Navigator.of(context).pop(_GoTo(i)),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                MadeenSpace.pageMargin,
                MadeenSpace.md,
                MadeenSpace.pageMargin,
                MadeenSpace.md,
              ),
              child: ExamQuestionGridLegend(),
            ),
            MadeenBottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const _OpenReview()),
                      child: Text(l10n.examReviewButton),
                    ),
                  ),
                  const SizedBox(width: MadeenSpace.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const _Submit()),
                      child: Text(l10n.examSubmitExamButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.active,
    required this.notifier,
    required this.enabled,
  });

  final ExamActive active;
  final ExamNotifier notifier;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MadeenBottomActionBar(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (enabled && !active.isFirstQuestion)
                  ? notifier.previousQuestion
                  : null,
              child: Text(l10n.examPreviousButton),
            ),
          ),
          const SizedBox(width: MadeenSpace.sm),
          Expanded(
            child: FilledButton(
              onPressed: !enabled
                  ? null
                  : active.isLastQuestion
                  ? () => context.push(AppRoutes.examSubmissionReview)
                  : notifier.nextQuestion,
              child: Text(
                active.isLastQuestion
                    ? l10n.examReviewButton
                    : l10n.examNextButton,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeoutOverlay extends StatelessWidget {
  const _TimeoutOverlay({required this.state, required this.notifier});

  final ExamState state;
  final ExamNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final isTimeout =
        state is ExamTimedOut ||
        (state is ExamSubmitting &&
            (state as ExamSubmitting).isTimeoutSubmission) ||
        (state is ExamError && (state as ExamError).wasTimeout);
    final isError = state is ExamError;

    return Positioned.fill(
      child: Container(
        color: t.canvas.withValues(alpha: 0.96),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(MadeenSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.timer_off_outlined,
                  size: 36,
                  color: isError ? t.error : t.attention,
                ),
                const SizedBox(height: MadeenSpace.md),
                Text(
                  isTimeout ? l10n.examTimeoutTitle : l10n.examSubmitting,
                  style: MadeenType.headlineMd.copyWith(color: t.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MadeenSpace.xs),
                if (isError)
                  Text(
                    localizedFailureMessage(l10n, (state as ExamError).failure),
                    textAlign: TextAlign.center,
                    style: MadeenType.bodyMd.copyWith(color: t.error),
                  )
                else if (isTimeout)
                  Text(
                    l10n.examTimeoutMessage,
                    textAlign: TextAlign.center,
                    style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (isError) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: notifier.retry,
                    child: Text(l10n.examRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
