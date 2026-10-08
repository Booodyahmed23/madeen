import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../domain/entities/ai_insight.dart';

/// One row inside a Strengths / Areas to Improve / Recurring Patterns
/// section. Icon **and** color communicate [insight.kind] (never color
/// alone — accessibility requirement from this phase's brief), matching
/// TopicPerformanceTile's own strong/needs-practice badge pattern; the
/// [kindLabel] the caller supplies (its section's own heading, e.g.
/// "Strengths") is prefixed into the semantic label for the same reason a
/// screen reader user gets, since the visual section heading isn't repeated
/// per-row.
class AiInsightTile extends StatelessWidget {
  const AiInsightTile({
    super.key,
    required this.insight,
    required this.kindLabel,
  });

  final AiInsight insight;
  final String kindLabel;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final (icon, color) = switch (insight.kind) {
      AiInsightKind.strength => (Icons.trending_up, t.success),
      AiInsightKind.weakness => (Icons.trending_down, t.error),
      AiInsightKind.pattern => (Icons.insights_outlined, t.accentText),
    };

    return Semantics(
      label: '$kindLabel: ${insight.text}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MadeenSpace.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: MadeenSpace.sm),
            Expanded(
              child: Text(
                insight.text,
                style: MadeenType.bodyMd.copyWith(color: t.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
