import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/topic_performance.dart';
import 'performance_format.dart';

/// One row on the Topic Performance screen (and the Overview preview list).
/// Strong / Needs Practice is shown as an icon **and** text badge, not color
/// alone — this phase's brief is explicit that performance indicators must
/// stay legible without relying on color perception.
class TopicPerformanceTile extends StatelessWidget {
  const TopicPerformanceTile({
    super.key,
    required this.topic,
    this.onAnalyzeWithAi,
  });

  final TopicPerformance topic;

  /// Set only by the Topic Performance screen (see
  /// topic_performance_screen.dart) — the AI Analysis feature's "Topic
  /// Details → Analyze with AI" entry point (Phase 7). `null` everywhere
  /// else (the Overview preview list, Attempt Details' topic breakdown)
  /// hides the action entirely, so this stays byte-identical to Phase 6 for
  /// every existing call site.
  final VoidCallback? onAnalyzeWithAi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final accuracy = topic.accuracyPercent;

    final (badgeIcon, badgeLabel, badgeColor) = topic.isStrong
        ? (Icons.trending_up, l10n.performanceStrongLabel, t.success)
        : topic.needsPractice
        ? (Icons.trending_down, l10n.performanceNeedsPracticeLabel, t.error)
        : (null, null, null);

    return Semantics(
      label:
          '${topic.topicName}: ${l10n.performanceAccuracyLabel} '
          '${accuracy.round()}%, ${l10n.performanceCorrectLabel} '
          '${topic.correct}, ${l10n.performanceWrongLabel} ${topic.wrong}'
          '${badgeLabel != null ? ', $badgeLabel' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MadeenSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                if (badgeIcon != null) ...[
                  Icon(badgeIcon, size: 16, color: badgeColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      badgeLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MadeenType.labelSm.copyWith(color: badgeColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${accuracy.round()}%',
                  style: MadeenType.metricMd.copyWith(color: t.ink),
                ),
                if (onAnalyzeWithAi != null)
                  IconButton(
                    onPressed: onAnalyzeWithAi,
                    tooltip: l10n.aiAnalysisAnalyzeWithAiButton,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: MadeenSpace.xs),
            // DESIGN.md pacing bar: a crisp 3px line on a hairline track.
            ClipRRect(
              borderRadius: BorderRadius.circular(MadeenRadius.base / 2),
              child: LinearProgressIndicator(
                value: (accuracy / 100).clamp(0, 1),
                minHeight: 3,
                backgroundColor: t.hairline,
                valueColor: AlwaysStoppedAnimation(badgeColor ?? t.accent),
              ),
            ),
            const SizedBox(height: MadeenSpace.xs),
            Text(
              '${l10n.performanceCorrectLabel}: ${topic.correct}  ·  '
              '${l10n.performanceWrongLabel}: ${topic.wrong}  ·  '
              '${l10n.performanceQuestionsLabel}: ${topic.questionsAttempted}'
              '${topic.averageTimePerQuestion != null ? '  ·  ${l10n.performanceAverageTimeLabel}: '
                        '${formatPerformanceDuration(topic.averageTimePerQuestion!)}' : ''}',
              style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
