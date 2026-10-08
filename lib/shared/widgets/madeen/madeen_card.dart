import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';

/// The three panel tones the MADEEN system uses.
enum MadeenCardTone {
  /// Level 1 monolith: surface + 1px hairline (the default card).
  surface,

  /// A recessed, quieter panel (e.g. an insight) — same hairline.
  muted,

  /// The deep Oxford-slate hero panel.
  hero,
}

/// A MADEEN panel: crisp corners, a 1px hairline, no floating shadow
/// (DESIGN.md "Elevation & Depth"). Optionally tappable as a whole.
class MadeenCard extends StatelessWidget {
  const MadeenCard({
    super.key,
    required this.child,
    this.onTap,
    this.tone = MadeenCardTone.surface,
    this.padding = const EdgeInsets.all(MadeenSpace.md + MadeenSpace.xxs),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final MadeenCardTone tone;
  final EdgeInsetsGeometry padding;

  /// When set, replaces the card's descendants in the semantics tree with
  /// this one label (used for whole-card tap targets).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final (background, border) = switch (tone) {
      MadeenCardTone.surface => (t.surface, t.hairline),
      MadeenCardTone.muted => (t.surfaceMuted, t.hairline),
      MadeenCardTone.hero => (t.hero, t.heroBorder),
    };
    final radius = BorderRadius.circular(MadeenRadius.card);

    final card = Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border, width: MadeenSize.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    final label = semanticLabel;
    if (label == null) return card;
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: card,
    );
  }
}
