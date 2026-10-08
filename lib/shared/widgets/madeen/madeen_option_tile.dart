import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';

/// A selectable option card — a radio mark, a title and a description
/// (e.g. a session's feedback mode). Selected: a 1.5px brass border and the
/// brass radio, per DESIGN.md's selected-state treatment; unselected: the
/// standard hairline card. Announced as a selectable, checked/unchecked
/// control.
class MadeenOptionTile extends StatelessWidget {
  const MadeenOptionTile({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final radius = BorderRadius.circular(MadeenRadius.card);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? t.accent : t.hairline,
            width: selected ? 1.5 : MadeenSize.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(MadeenSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? t.accent : t.inkTertiary,
                ),
                const SizedBox(width: MadeenSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MadeenType.bodyMd.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: MadeenSpace.xxs),
                      Text(
                        description,
                        style: MadeenType.bodySm.copyWith(
                          color: t.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
