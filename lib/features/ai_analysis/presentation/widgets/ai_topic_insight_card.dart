import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../domain/entities/ai_topic_insight.dart';

/// One row in the Topic Insights section — factual accuracy (from the same
/// data Topic Performance already shows) alongside the AI's interpretation
/// and recommended action. Tappable (into that topic's own dedicated Topic
/// AI Insight screen) only when [onTap] is given.
class AiTopicInsightCard extends StatelessWidget {
  const AiTopicInsightCard({super.key, required this.insight, this.onTap});

  final AiTopicInsight insight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);

    return Semantics(
      label:
          '${insight.topicName}: ${insight.accuracyPercent.round()}%. '
          '${insight.interpretation} ${insight.recommendedAction}',
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MadeenRadius.base),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: MadeenSpace.xxs),
          padding: const EdgeInsets.all(MadeenSpace.sm + 2),
          decoration: BoxDecoration(
            color: t.neutralFill,
            borderRadius: BorderRadius.circular(MadeenRadius.base),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      insight.topicName,
                      style: MadeenType.bodyMd.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${insight.accuracyPercent.round()}%',
                    style: MadeenType.metricMd.copyWith(color: t.ink),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: t.inkTertiary),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                insight.interpretation,
                style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right_alt, size: 16, color: t.accentText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      insight.recommendedAction,
                      style: MadeenType.bodySm.copyWith(color: t.ink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
