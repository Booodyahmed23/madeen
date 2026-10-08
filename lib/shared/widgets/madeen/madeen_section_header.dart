import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';

/// A section eyebrow — the small, tracked, upper-case label that opens each
/// MADEEN panel ("PERFORMANCE SNAPSHOT"), with an optional leading icon and
/// an optional trailing widget (a link, an icon, a count).
///
/// Upper-casing is applied here, at render time, so localized strings stay
/// in their natural case everywhere else (it is a no-op for Arabic).
class MadeenSectionHeader extends StatelessWidget {
  const MadeenSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.color,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  /// Overrides the label color (e.g. on the hero panel).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final labelColor = color ?? t.inkSecondary;

    return LayoutBuilder(
      builder: (context, constraints) =>
          _row(context, constraints.maxWidth / 2, labelColor, t),
    );
  }

  Widget _row(
    BuildContext context,
    double maxTrailingWidth,
    Color labelColor,
    MadeenTokens t,
  ) {
    final icon = this.icon;
    final trailing = this.trailing;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: t.accentText),
          const SizedBox(width: MadeenSpace.xs),
        ],
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: MadeenType.eyebrow(context).copyWith(color: labelColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: MadeenSpace.xs),
          // Natural width, pinned to the end — but never more than half the
          // row, so on narrow screens / large text a long link ellipsizes
          // instead of pushing past the edge.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTrailingWidth),
            child: trailing,
          ),
        ],
      ],
    );
  }
}

/// A compact trailing link for a [MadeenSectionHeader] ("See Performance ›").
/// Purely visual — the enclosing card owns the tap target.
class MadeenHeaderLink extends StatelessWidget {
  const MadeenHeaderLink({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MadeenType.labelMd.copyWith(
              color: t.accentText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: t.accentText),
      ],
    );
  }
}
