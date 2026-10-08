import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/question_review_item.dart';
import '../providers/study_session_notifier.dart';
import '../providers/study_session_state.dart';

/// Per-question review after submission — everything shown here comes from
/// the backend-sourced [QuestionReviewItem] list, never recomputed from
/// what was shown during the session.
class QuestionReviewScreen extends ConsumerWidget {
  const QuestionReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(studySessionNotifierProvider);

    if (state is! StudySessionCompleted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studySessionReviewTitle)),
        body: Center(child: Text(l10n.studySessionGenericError)),
      );
    }

    if (state.review.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.studySessionReviewTitle)),
        body: MadeenPageMessage(message: l10n.studySessionReviewEmpty),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studySessionReviewTitle)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            MadeenSpace.pageMargin,
            MadeenSpace.lg,
            MadeenSpace.pageMargin,
            MadeenSpace.xl,
          ),
          itemCount: state.review.length,
          separatorBuilder: (context, _) =>
              const SizedBox(height: MadeenSpace.sm),
          itemBuilder: (context, index) =>
              _ReviewCard(item: state.review[index], index: index),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.index});

  final QuestionReviewItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final statusColor = switch (item.isCorrect) {
      true => t.success,
      false => t.error,
      null => t.inkTertiary,
    };

    String choiceText(String? choiceId) {
      if (choiceId == null) return l10n.studySessionReviewNoAnswer;
      final match = item.choices.where((c) => c.id == choiceId);
      return match.isEmpty ? choiceId : match.first.text;
    }

    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: MadeenSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: MadeenType.eyebrow(context).copyWith(color: t.inkSecondary),
          ),
          const SizedBox(height: 2),
          MadeenContentText(
            value,
            style: MadeenType.bodyMd.copyWith(color: t.ink),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(MadeenSpace.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(MadeenRadius.card),
        border: Border.all(color: statusColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (item.isCorrect) {
                  true => Icons.check_circle,
                  false => Icons.cancel,
                  null => Icons.remove_circle_outline,
                },
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: MadeenSpace.xs),
              Expanded(
                child: MadeenContentText(
                  '${index + 1}. ${item.questionText}',
                  style: MadeenType.bodyMd.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          field(
            l10n.studySessionReviewYourAnswerLabel,
            choiceText(item.selectedChoiceId),
          ),
          field(
            l10n.studySessionReviewCorrectAnswerLabel,
            item.correctChoiceId == null
                ? l10n.studySessionReviewCorrectAnswerHidden
                : choiceText(item.correctChoiceId),
          ),
          if (item.explanation != null && item.explanation!.isNotEmpty)
            field(l10n.studySessionExplanationLabel, item.explanation!),
        ],
      ),
    );
  }
}
