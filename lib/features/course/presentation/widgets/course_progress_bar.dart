import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// A thin linear progress bar + percent label — reused by the Course list
/// tile and Course Details header so both always render the exact same
/// `Course.completionPercent` value the same way, matching the "percent
/// shown identically wherever it appears" rule `AccuracyRing` already
/// follows for Performance. Drawn as DESIGN.md's pacing bar: a crisp 3px
/// brass line on a hairline track.
class CourseProgressBar extends StatelessWidget {
  const CourseProgressBar({super.key, required this.percent});

  /// 0–100.
  final double percent;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final clamped = percent.clamp(0, 100);

    return Semantics(
      label: '${clamped.round()}%',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MadeenRadius.base / 2),
              child: LinearProgressIndicator(
                value: clamped / 100,
                minHeight: 3,
                backgroundColor: t.hairline,
                color: t.accent,
              ),
            ),
          ),
          const SizedBox(width: MadeenSpace.xs),
          Text(
            '${clamped.round()}%',
            style: MadeenType.labelMd.copyWith(
              color: t.inkSecondary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
