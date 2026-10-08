import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// "{current} / {total}" text plus a thin linear indicator — the one place
/// progress is rendered so the active-session and submission-review screens
/// show it identically. Deliberately just this: no per-question dot grid or
/// other heavier visualization, per the "don't overload the UI" guidance.
class SessionProgressBar extends StatelessWidget {
  const SessionProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  /// 1-based question number currently shown.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fraction = total == 0 ? 0.0 : current / total;

    return Semantics(
      label: l10n.studySessionProgressSemanticLabel(current, total),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.studySessionProgressLabel(current, total),
              style: MadeenType.labelMd.copyWith(
                color: MadeenTokens.of(context).inkSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: MadeenSpace.xs),
            // DESIGN.md pacing bar: a crisp 3px brass line on a hairline.
            ClipRRect(
              borderRadius: BorderRadius.circular(MadeenRadius.base / 2),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
