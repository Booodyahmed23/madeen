import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// A circular accuracy/score indicator. Deliberately shows the percentage
/// as text at the center rather than relying on the ring's fill alone —
/// accessibility requirement from this phase's brief ("performance
/// indicators must not depend on color alone") — and the [Semantics] label
/// carries the same number for screen readers, which don't see the ring at
/// all.
class AccuracyRing extends StatelessWidget {
  const AccuracyRing({
    super.key,
    required this.percent,
    required this.label,
    required this.semanticLabel,
    this.size = 136,
  });

  /// 0–100. Values outside that range are clamped, not asserted — a
  /// malformed backend response should degrade gracefully here, same
  /// posture as everywhere else in this feature.
  final double percent;
  final String label;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final clamped = percent.clamp(0, 100).toDouble();

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // A fine brass ring on a hairline track — measured, not loud.
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: clamped / 100,
                strokeWidth: 6,
                backgroundColor: t.hairline,
                valueColor: AlwaysStoppedAnimation(t.accent),
              ),
            ),
            // Inner text scales down to fit the circle at any text size.
            Padding(
              padding: const EdgeInsets.all(MadeenSpace.md + 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${clamped.round()}%',
                      style: MadeenType.metricLg.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      style: MadeenType.eyebrow(context)
                          .copyWith(color: t.inkSecondary),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
