import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/question_feedback.dart';

/// Immediate-feedback mode only: shown after a question is submitted.
/// Everything on this panel comes straight from the repository-sourced
/// [QuestionFeedback] — nothing here is computed client-side.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.feedback});

  final QuestionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final isCorrect = feedback.isCorrect;
    final color = isCorrect ? t.success : t.error;
    final explanation = feedback.explanation;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: MadeenSpace.xs),
        padding: const EdgeInsets.all(MadeenSpace.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(MadeenRadius.card),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: MadeenSpace.xs),
                Text(
                  isCorrect
                      ? l10n.studySessionCorrectLabel
                      : l10n.studySessionIncorrectLabel,
                  style: MadeenType.headlineSm.copyWith(color: color),
                ),
              ],
            ),
            if (explanation != null && explanation.isNotEmpty) ...[
              const SizedBox(height: MadeenSpace.sm),
              Text(
                l10n.studySessionExplanationLabel.toUpperCase(),
                style: MadeenType.eyebrow(context)
                    .copyWith(color: t.inkSecondary),
              ),
              const SizedBox(height: MadeenSpace.xxs),
              MadeenContentText(
                explanation,
                style: MadeenType.bodyMd.copyWith(color: t.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
