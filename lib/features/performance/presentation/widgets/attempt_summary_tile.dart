import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/attempt_summary.dart';
import '../../domain/entities/attempt_type.dart';
import 'performance_format.dart';

/// One row in Attempt History (and the Overview preview list). Study
/// Session vs. Exam Simulation is shown as an icon **and** text label, not
/// color alone, matching TopicPerformanceTile's accessibility posture.
class AttemptSummaryTile extends StatelessWidget {
  const AttemptSummaryTile({super.key, required this.attempt, this.onTap});

  final AttemptSummary attempt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isStudySession = attempt.type == AttemptType.studySession;
    final typeLabel = isStudySession
        ? l10n.performanceStudySessionLabel
        : l10n.performanceExamSimulationLabel;
    final typeIcon = isStudySession
        ? Icons.menu_book_outlined
        : Icons.timer_outlined;
    final dateLabel = formatPerformanceDate(context, attempt.completedAt);
    final questionsLabel = l10n.performanceAttemptQuestionsCount(
      attempt.totalQuestions,
    );
    final scoreLabel = '${attempt.scorePercent.round()}%';

    return MadeenListRow(
      icon: typeIcon,
      title: attempt.contentLabel.isEmpty ? typeLabel : attempt.contentLabel,
      subtitle: '$dateLabel · $typeLabel · $questionsLabel',
      trailingValue: scoreLabel,
      onTap: onTap,
      semanticLabel:
          '$dateLabel, $typeLabel, ${attempt.contentLabel}, '
          '$questionsLabel, ${l10n.performanceScoreLabel} $scoreLabel',
    );
  }
}
