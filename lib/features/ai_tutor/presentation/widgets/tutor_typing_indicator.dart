import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';

/// Shown while [TutorConversationState.isSending] is true — styled like an
/// assistant bubble so it reads as "the assistant is about to say
/// something" rather than a generic loading spinner. Deliberately static
/// (no animation) per this app's own "avoid excessive animations" design
/// direction.
class TutorTypingIndicator extends StatelessWidget {
  const TutorTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        label: l10n.aiTutorTypingIndicator,
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: MadeenSpace.xxs),
          padding: const EdgeInsets.symmetric(
            horizontal: MadeenSpace.sm + 2,
            vertical: MadeenSpace.sm,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(MadeenRadius.card),
            border: Border.all(color: t.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.accent,
                ),
              ),
              const SizedBox(width: MadeenSpace.xs + 2),
              Text(
                l10n.aiTutorTypingIndicator,
                style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
