import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// One row in any curriculum list (Programs/Parts/Units/Sub-units/Topics) —
/// kept as a single widget so all five levels look and behave identically.
class CurriculumListTile extends StatelessWidget {
  const CurriculumListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
  });

  /// `null` disables the row like MadeenFeatureTile: muted text, no
  /// chevron, not tappable.

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final subtitle = this.subtitle;
    final leading = this.leading;

    final enabled = onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.xs),
      child: MadeenCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: MadeenSpace.md,
          // Keeps the tap target comfortably above the ~48dp minimum even
          // with a single line of text.
          vertical: MadeenSpace.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: MadeenSpace.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: MadeenType.headlineSm.copyWith(
                      color: enabled ? t.ink : t.inkSecondary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: MadeenSpace.xxs),
                    Text(
                      subtitle,
                      style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: MadeenSpace.xs),
            // chevron_right mirrors itself in RTL (matchTextDirection) —
            // picking chevron_left for RTL would double-flip it backwards.
            if (enabled) Icon(Icons.chevron_right, color: t.inkTertiary),
          ],
        ),
      ),
    );
  }
}
