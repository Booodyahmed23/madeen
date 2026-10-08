import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// "Question {current} / {total}" plus a thin linear indicator — the exam
/// equivalent of study_session's `SessionProgressBar`, kept as its own
/// widget because the label wording and l10n keys are exam-specific (no
/// topic/session context ever appears here, by design).
class ExamProgressBar extends StatelessWidget {
  const ExamProgressBar({
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
      label: l10n.examProgressSemanticLabel(current, total),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.examProgressLabel(current, total),
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
