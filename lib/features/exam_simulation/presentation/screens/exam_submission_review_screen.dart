import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../core/error/failure_messages.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/exam_notifier.dart';
import '../providers/exam_state.dart';
import '../widgets/exam_submit_confirmation.dart';

enum _QuestionStatus { answered, unanswered, flagged, answeredAndFlagged }

/// The pre-submission "Exam Review" screen — shows answered/unanswered/
/// flagged counts, a full per-question status list, and requires an
/// explicit confirmation before final submission. Submission is a
/// deliberate, separate action here, never a side effect of reaching the
/// last question in the active exam.
class ExamSubmissionReviewScreen extends ConsumerWidget {
  const ExamSubmissionReviewScreen({super.key});

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

    final active = switch (state) {
      ExamActive s => s,
      ExamSubmitting s => s.active,
      ExamError(:final retryFrom?) => retryFrom,
      _ => null,
    };

    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.examSubmissionReviewTitle)),
        body: Center(child: Text(l10n.examGenericError)),
      );
    }

    final isSubmitting = state is ExamSubmitting;
    final failure = state is ExamError ? state.failure : null;

    _QuestionStatus statusFor(String questionId) {
      final answered = active.selectedAnswers.containsKey(questionId);
      final flagged = active.flaggedQuestionIds.contains(questionId);
      if (answered && flagged) return _QuestionStatus.answeredAndFlagged;
      if (flagged) return _QuestionStatus.flagged;
      if (answered) return _QuestionStatus.answered;
      return _QuestionStatus.unanswered;
    }

    String labelFor(_QuestionStatus status) => switch (status) {
      _QuestionStatus.answered => l10n.examQuestionStatusAnswered,
      _QuestionStatus.unanswered => l10n.examQuestionStatusUnanswered,
      _QuestionStatus.flagged => l10n.examQuestionStatusFlagged,
      _QuestionStatus.answeredAndFlagged =>
        l10n.examQuestionStatusAnsweredFlagged,
    };

    Color colorFor(_QuestionStatus status, MadeenTokens t) => switch (status) {
      _QuestionStatus.answered => t.success,
      _QuestionStatus.unanswered => t.error,
      // DESIGN.md "Flagged State": terracotta attention.
      _QuestionStatus.flagged => t.attention,
      _QuestionStatus.answeredAndFlagged => t.attention,
    };

    void goToFirst(bool Function(_QuestionStatus) match) {
      for (var i = 0; i < active.questions.length; i++) {
        if (match(statusFor(active.questions[i].id))) {
          notifier.goToQuestion(i);
          context.pop();
          return;
        }
      }
    }

    final t = MadeenTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.examSubmissionReviewTitle)),
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
                  Text(
                    l10n.examReviewQuestionsCount(active.totalQuestions),
                    style: MadeenType.headlineMd.copyWith(color: t.ink),
                  ),
                  const SizedBox(height: MadeenSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _CountCard(
                          label: l10n.examAnsweredCount(active.answeredCount),
                          color: t.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CountCard(
                          label: l10n.examUnansweredCount(
                            active.unansweredCount,
                          ),
                          color: t.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CountCard(
                          label: l10n.examFlaggedCount(active.flaggedCount),
                          color: t.attention,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: active.unansweredCount == 0
                              ? null
                              : () => goToFirst(
                                  (s) => s == _QuestionStatus.unanswered,
                                ),
                          child: Text(
                            l10n.examReviewUnansweredButton,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: active.flaggedCount == 0
                              ? null
                              : () => goToFirst(
                                  (s) =>
                                      s == _QuestionStatus.flagged ||
                                      s == _QuestionStatus.answeredAndFlagged,
                                ),
                          child: Text(
                            l10n.examReviewFlaggedButton,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < active.questions.length; i++)
                    _QuestionStatusTile(
                      label: l10n.examGoToQuestion(i + 1),
                      statusLabel: labelFor(statusFor(active.questions[i].id)),
                      color: colorFor(statusFor(active.questions[i].id), t),
                      onTap: () {
                        notifier.goToQuestion(i);
                        context.pop();
                      },
                    ),
                  if (failure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizedFailureMessage(l10n, failure),
                      style: MadeenType.bodySm.copyWith(color: t.error),
                    ),
                  ],
                ],
              ),
            ),
            MadeenBottomActionBar(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.examReturnToExamButton),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (await confirmExamSubmission(
                              context,
                              unansweredCount: active.unansweredCount,
                            )) {
                              await notifier.submitExam();
                            }
                          },
                    child: isSubmitting
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(l10n.examSubmitting),
                            ],
                          )
                        : Text(l10n.examSubmitExamButton),
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

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: MadeenSpace.sm,
        horizontal: MadeenSpace.xs,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(MadeenRadius.card),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: MadeenType.labelMd.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _QuestionStatusTile extends StatelessWidget {
  const _QuestionStatusTile({
    required this.label,
    required this.statusLabel,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String statusLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MadeenSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: MadeenType.bodyMd.copyWith(color: t.ink),
                ),
              ),
              // A status pill (DESIGN.md "Micro-Tags").
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MadeenSpace.sm,
                  vertical: MadeenSpace.xxs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MadeenRadius.pill),
                  border: Border.all(color: color),
                ),
                child: Text(
                  statusLabel,
                  style: MadeenType.labelSm.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
