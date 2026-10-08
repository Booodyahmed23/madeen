import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';

/// One metric in a telemetry group: a large tabular figure over an
/// upper-case caption, on a subtle neutral fill (DESIGN.md "Tabular Score &
/// Telemetry Meters"). [emphasize] tints the figure with the brand accent —
/// reserved for the one headline metric of a group.
class MadeenMetricTile extends StatelessWidget {
  const MadeenMetricTile({
    super.key,
    required this.value,
    required this.label,
    this.emphasize = false,
    this.valueColor,
  });

  final String value;
  final String label;
  final bool emphasize;

  /// Overrides the figure's color for a semantic metric (e.g. correct /
  /// wrong counts in the success / error tokens).
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MadeenSpace.sm,
          vertical: MadeenSpace.md,
        ),
        decoration: BoxDecoration(
          color: t.neutralFill,
          borderRadius: BorderRadius.circular(MadeenRadius.base),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: MadeenType.metricLg.copyWith(
                  color: valueColor ?? (emphasize ? t.accentText : t.ink),
                ),
              ),
            ),
            const SizedBox(height: MadeenSpace.xxs),
            Text(
              label.toUpperCase(),
              style: MadeenType.eyebrow(context)
                  .copyWith(color: t.inkSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single hero figure — an upper-case caption over a large tabular number
/// (a session/exam score). Centered; scales down rather than overflowing.
class MadeenScoreDisplay extends StatelessWidget {
  const MadeenScoreDisplay({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: MadeenType.eyebrow(context).copyWith(color: t.inkSecondary),
          ),
          const SizedBox(height: MadeenSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: MadeenType.metricXl.copyWith(color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}
