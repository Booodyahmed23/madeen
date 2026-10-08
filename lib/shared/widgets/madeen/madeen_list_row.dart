import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';

/// One row of a MADEEN list: an icon well, a title over a metadata line, and
/// an optional trailing figure — rows are separated by hairlines by the
/// caller (see [MadeenDividedList]). Chevrons mirror in RTL.
class MadeenListRow extends StatelessWidget {
  const MadeenListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingValue,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// A short tabular figure shown at the trailing edge ("90%").
  final String? trailingValue;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final trailingValue = this.trailingValue;

    final row = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MadeenRadius.base),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MadeenSpace.sm),
        child: Row(
          children: [
            Container(
              width: MadeenSize.iconWell,
              height: MadeenSize.iconWell,
              decoration: BoxDecoration(
                color: t.neutralFill,
                borderRadius: BorderRadius.circular(MadeenRadius.base),
              ),
              child: Icon(icon, size: 20, color: t.inkSecondary),
            ),
            const SizedBox(width: MadeenSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MadeenType.bodyMd.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                  ),
                ],
              ),
            ),
            if (trailingValue != null) ...[
              const SizedBox(width: MadeenSpace.sm),
              Text(
                trailingValue,
                style: MadeenType.metricMd.copyWith(color: t.ink),
              ),
            ],
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: t.inkTertiary),
          ],
        ),
      ),
    );

    final label = semanticLabel;
    if (label == null) return row;
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: row,
    );
  }
}

/// Stacks [children] separated by 1px hairlines.
class MadeenDividedList extends StatelessWidget {
  const MadeenDividedList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: t.hairline),
          children[i],
        ],
      ],
    );
  }
}
