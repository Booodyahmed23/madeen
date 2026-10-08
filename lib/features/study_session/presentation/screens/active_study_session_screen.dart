import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/session_config.dart';
import '../providers/study_session_notifier.dart';
import '../providers/study_session_state.dart';
import '../widgets/answer_choice_tile.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/session_progress_bar.dart';
import '../widgets/session_timer_display.dart';

/// The question-answering loop. Reads [StudySessionActive] exclusively —
/// if the session isn't active (e.g. a stray back/forward after it already
/// ended), it falls back to a simple "no active session" state rather than
/// crashing on a null question.
class ActiveStudySessionScreen extends ConsumerWidget {
  const ActiveStudySessionScreen({super.key});

  Future<bool> _confirmLeave(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.studySessionLeaveSessionTitle),
        content: Text(l10n.studySessionLeaveSessionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.studySessionLeaveSessionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.studySessionLeaveSessionConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(studySessionNotifierProvider);
    final notifier = ref.read(studySessionNotifierProvider.notifier);

    // The notifier never puts an empty question list into StudySessionActive
    // (see study_session_notifier.dart's startSession), but this screen
    // guards against it too rather than trusting that invariant blindly.
    if (state is! StudySessionActive || state.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studySessionSetupTitle)),
        body: Center(child: Text(l10n.studySessionGenericError)),
      );
    }

    final question = state.currentQuestion;
    final selectedChoiceId = state.selectedChoiceForCurrent;
    final feedback = state.feedbackForCurrent;
    final isImmediate = state.config.feedbackMode == FeedbackMode.immediate;
    final showFeedback = isImmediate && state.phase == QuestionPhase.feedback;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave(context)) {
          notifier.reset();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.config.topicName),
          actions: [
            IconButton(
              tooltip: state.isPaused
                  ? l10n.studySessionResumeButton
                  : l10n.studySessionPauseButton,
              icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: notifier.togglePause,
            ),
            IconButton(
              tooltip: l10n.studySessionReviewAndSubmitButton,
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () =>
                  context.push(AppRoutes.studySessionSubmissionReview),
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
                          child: SessionProgressBar(
                            current: state.currentIndex + 1,
                            total: state.totalQuestions,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SessionTimerDisplay(
                          elapsed: state.elapsed,
                          isPaused: state.isPaused,
                        ),
                      ],
                    ),
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
                        // DESIGN.md: answer clusters keep a fixed 12px gap
                        // for thumb ergonomics under time pressure.
                        for (final choice in question.choices)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: MadeenSpace.sm,
                            ),
                            child: AnswerChoiceTile(
                              choice: choice,
                              isSelected: choice.id == selectedChoiceId,
                              isLocked: showFeedback,
                              isCorrectChoice: feedback == null
                                  ? null
                                  : choice.id == feedback.correctChoiceId,
                              onTap: () => notifier.selectChoice(choice.id),
                            ),
                          ),
                        if (showFeedback && feedback != null)
                          FeedbackPanel(feedback: feedback),
                        if (!isImmediate ||
                            state.phase != QuestionPhase.feedback) ...[
                          if (selectedChoiceId == null) ...[
                            const SizedBox(height: MadeenSpace.xs),
                            Text(
                              l10n.studySessionSelectAnswerHint,
                              style: MadeenType.bodySm.copyWith(
                                color: MadeenTokens.of(context).inkSecondary,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  _BottomBar(
                    state: state,
                    notifier: notifier,
                    isImmediate: isImmediate,
                    showFeedback: showFeedback,
                  ),
                ],
              ),
              if (state.isPaused) _PausedOverlay(l10n: l10n),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.notifier,
    required this.isImmediate,
    required this.showFeedback,
  });

  final StudySessionActive state;
  final StudySessionNotifier notifier;
  final bool isImmediate;
  final bool showFeedback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canSubmitAnswer =
        isImmediate &&
        state.phase == QuestionPhase.answering &&
        state.selectedChoiceForCurrent != null;

    return MadeenBottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canSubmitAnswer) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isSubmittingAnswer
                    ? null
                    : () => notifier.submitCurrentAnswer(),
                child: state.isSubmittingAnswer
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.studySessionSubmitAnswerButton),
              ),
            ),
            const SizedBox(height: MadeenSpace.xs),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isFirstQuestion
                      ? null
                      : notifier.previousQuestion,
                  child: Text(l10n.studySessionPreviousButton),
                ),
              ),
              const SizedBox(width: MadeenSpace.sm),
              Expanded(
                child: FilledButton(
                  onPressed: state.isLastQuestion
                      ? () =>
                            context.push(AppRoutes.studySessionSubmissionReview)
                      : notifier.nextQuestion,
                  child: Text(
                    state.isLastQuestion
                        ? l10n.studySessionReviewAndSubmitButton
                        : l10n.studySessionNextButton,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: MadeenTokens.of(context).canvas.withValues(alpha: 0.94),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pause_circle_outline,
                size: 36,
                color: MadeenTokens.of(context).accent,
              ),
              const SizedBox(height: MadeenSpace.sm),
              Text(
                l10n.studySessionPausedMessage,
                style: MadeenType.headlineMd.copyWith(
                  color: MadeenTokens.of(context).ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
