import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';
import 'madeen_card.dart';

/// An entry-point tile: accent icon and a "go" arrow on top, a serif title,
/// and a short description (the reference's bottom tiles). [onTap] `null`
/// renders it visibly disabled — muted, no arrow, not announced as a button.
class MadeenFeatureTile extends StatelessWidget {
  const MadeenFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final enabled = onTap != null;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return MadeenCard(
      onTap: onTap,
      semanticLabel: '$title, $subtitle',
      padding: const EdgeInsets.all(MadeenSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? t.accentText : t.inkTertiary,
              ),
              const Spacer(),
              if (enabled)
                // "Go" arrow points to the reading-end corner in both LTR
                // and RTL (north_east has no automatic mirroring).
                Transform.flip(
                  flipX: isRtl,
                  child: Icon(Icons.north_east, size: 18, color: t.inkTertiary),
                ),
            ],
          ),
          const SizedBox(height: MadeenSpace.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MadeenType.headlineSm.copyWith(
              color: enabled ? t.ink : t.inkSecondary,
            ),
          ),
          const SizedBox(height: MadeenSpace.xxs),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
          ),
        ],
      ),
    );
  }
}
