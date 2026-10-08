import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../domain/entities/ai_recommendation.dart';

/// One row in the Recommended Next Steps section — tappable (with a
/// trailing chevron) only when [onTap] is given, which the caller supplies
/// solely when [recommendation.topicId] is present (see
/// ai_analysis_overview_screen.dart), so a student can jump straight from
/// "review Cost Management" into that topic's own AI Insight.
class AiRecommendationTile extends StatelessWidget {
  const AiRecommendationTile({
    super.key,
    required this.recommendation,
    this.onTap,
  });

  final AiRecommendation recommendation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);

    return Semantics(
      label: recommendation.text,
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MadeenRadius.base),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: MadeenSpace.xxs),
          padding: const EdgeInsets.all(MadeenSpace.sm),
          decoration: BoxDecoration(
            color: t.neutralFill,
            borderRadius: BorderRadius.circular(MadeenRadius.base),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_right_alt, size: 18, color: t.accentText),
              const SizedBox(width: MadeenSpace.xs),
              Expanded(
                child: Text(
                  recommendation.text,
                  style: MadeenType.bodyMd.copyWith(color: t.ink),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 18, color: t.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
