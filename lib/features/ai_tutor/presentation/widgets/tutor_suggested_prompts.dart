import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';

/// A handful of tappable starter questions shown only on an empty
/// conversation — tapping one sends it through the exact same
/// [TutorConversationNotifier.sendMessage] path as typing it would, never
/// a separate "canned answer" shortcut.
class TutorSuggestedPrompts extends StatelessWidget {
  const TutorSuggestedPrompts({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prompts = [
      l10n.aiTutorSuggestedPrompt1,
      l10n.aiTutorSuggestedPrompt2,
      l10n.aiTutorSuggestedPrompt3,
      l10n.aiTutorSuggestedPrompt4,
    ];

    final t = MadeenTokens.of(context);

    // Full-width rows rather than chips: a starter question can be longer
    // than one line, and a chip would clip it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: MadeenSpace.xs),
            child: MadeenCard(
              onTap: () => onSelected(prompt),
              semanticLabel: prompt,
              padding: const EdgeInsets.symmetric(
                horizontal: MadeenSpace.md,
                vertical: MadeenSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      prompt,
                      style: MadeenType.bodyMd.copyWith(color: t.ink),
                    ),
                  ),
                  const SizedBox(width: MadeenSpace.xs),
                  Icon(Icons.arrow_forward, size: 18, color: t.accentText),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
