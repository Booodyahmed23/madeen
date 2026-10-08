import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../core/error/failure_messages.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/study_session_notifier.dart';
import '../providers/study_session_state.dart';

/// A confirmation step between answering and final submission — shows
/// answered/unanswered counts and lets the student jump back to any
/// unanswered question before committing. Submission is a deliberate,
/// separate action here, never a side effect of pressing Next in the
/// active-session screen.
class SubmissionReviewScreen extends ConsumerWidget {
  const SubmissionReviewScreen({super.key});

  Future<bool> _confirmSubmit(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.studySessionSubmitConfirmTitle),
        content: Text(l10n.studySessionSubmitConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.studySessionSubmitConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.studySessionSubmitConfirmConfirm),
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

    ref.listen<StudySessionState>(studySessionNotifierProvider, (
      previous,
      next,
    ) {
      if (next is StudySessionCompleted) {
        context.pushReplacement(AppRoutes.studySessionResults);
      }
    });

    // Submitting and Completed both keep rendering the last known Active
    // snapshot underneath (Submitting carries it; Completed has already
    // navigated away by the time this rebuilds) so the screen never goes
    // blank mid-transition.
    final active = switch (state) {
      StudySessionActive s => s,
      StudySessionSubmitting s => s.active,
      StudySessionError(:final retryFrom?) => retryFrom,
      _ => null,
    };

    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studySessionSubmissionReviewTitle)),
        body: Center(child: Text(l10n.studySessionGenericError)),
      );
    }

    final isSubmitting = state is StudySessionSubmitting;
    final failure = state is StudySessionError ? state.failure : null;
    final unansweredIndexes = [
      for (var i = 0; i < active.questions.length; i++)
        if (!active.selectedAnswers.containsKey(active.questions[i].id)) i,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studySessionSubmissionReviewTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MadeenSpace.pageMargin,
                  MadeenSpace.lg,
                  MadeenSpace.pageMargin,
                  MadeenSpace.lg,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CountCard(
                          label: l10n.studySessionAnsweredCount(
                            active.answeredCount,
                          ),
                          color: MadeenTokens.of(context).success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CountCard(
                          label: l10n.studySessionUnansweredCount(
                            active.unansweredCount,
                          ),
                          color: MadeenTokens.of(context).error,
                        ),
                      ),
                    ],
                  ),
                  if (unansweredIndexes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.studySessionUnansweredWarning,
                      style: MadeenType.bodyMd.copyWith(
                        color: MadeenTokens.of(context).ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: unansweredIndexes
                          .map(
                            (index) => ActionChip(
                              label: Text(
                                l10n.studySessionGoToQuestion(index + 1),
                              ),
                              onPressed: () {
                                notifier.goToQuestion(index);
                                context.pop();
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (failure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizedFailureMessage(l10n, failure),
                      style: MadeenType.bodySm.copyWith(
                        color: MadeenTokens.of(context).error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            MadeenBottomActionBar(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(MadeenSize.buttonHeight),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (await _confirmSubmit(context)) {
                          await notifier.submitSession();
                        }
                      },
                child: isSubmitting
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(l10n.studySessionSubmitting),
                        ],
                      )
                    : Text(l10n.studySessionSubmitSessionButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: MadeenSpace.md,
        horizontal: MadeenSpace.sm,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(MadeenRadius.card),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: MadeenType.bodyMd.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
