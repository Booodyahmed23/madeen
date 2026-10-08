import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';

/// Lays [children] out two per row, each row as tall as its tallest child —
/// sized by content (never a fixed aspect ratio), so long labels, large
/// text scales and Arabic never overflow. An odd last child keeps half width.
class MadeenPairGrid extends StatelessWidget {
  const MadeenPairGrid({
    super.key,
    required this.children,
    this.spacing = MadeenSpace.xs,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: spacing),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
