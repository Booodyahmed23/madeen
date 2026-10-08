import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// The AI's headline sentence for a screen (overall / topic / attempt
/// analysis), in the same recessed panel Home and Performance use for the
/// AI layer — the interpretive tone, visually set apart from factual
/// metrics, with no "AI magic" decoration.
class AiSummaryPanel extends StatelessWidget {
  const AiSummaryPanel({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return MadeenCard(
      tone: MadeenCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadeenSectionHeader(title: title, icon: Icons.psychology_outlined),
          const SizedBox(height: MadeenSpace.sm),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: t.ink),
          ),
        ],
      ),
    );
  }
}
