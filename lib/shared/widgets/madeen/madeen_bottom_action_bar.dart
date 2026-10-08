import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';

/// The pinned footer that holds a screen's primary action (Start session,
/// Save, Submit) — the canvas color with a single hairline above it, so
/// the action stays reachable while the content scrolls behind it.
class MadeenBottomActionBar extends StatelessWidget {
  const MadeenBottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.canvas,
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MadeenSpace.pageMargin,
          MadeenSpace.sm,
          MadeenSpace.pageMargin,
          MadeenSpace.sm,
        ),
        child: child,
      ),
    );
  }
}
