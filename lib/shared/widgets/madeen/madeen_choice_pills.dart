import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';

/// One option of a [MadeenChoicePills] group.
class MadeenChoice<T> {
  const MadeenChoice({required this.value, required this.label});

  final T value;
  final String label;
}

/// A single-select group of capsule pills (DESIGN.md "Micro-Tags" /
/// segmented controls) for filters and small option sets. Unlike a
/// segmented button it **wraps** onto further lines on narrow screens or
/// at large text sizes instead of overflowing, and each pill is a standard
/// [ChoiceChip] (selected state announced to screen readers), styled by the
/// MADEEN chip theme.
class MadeenChoicePills<T> extends StatelessWidget {
  const MadeenChoicePills({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<MadeenChoice<T>> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MadeenSpace.xs,
      runSpacing: MadeenSpace.xs,
      children: [
        for (final choice in choices)
          ChoiceChip(
            label: Text(choice.label),
            selected: choice.value == selected,
            onSelected: (_) => onSelected(choice.value),
          ),
      ],
    );
  }
}
