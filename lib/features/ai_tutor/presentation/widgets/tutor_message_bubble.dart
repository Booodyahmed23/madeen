import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/tutor_message.dart';
import 'tutor_format.dart';

/// One message bubble — aligned end on the solid primary-action tone for
/// the student, start on a hairline surface panel for the assistant. The two roles are told
/// apart by alignment *and* color *and* an accessible role label (never
/// color alone, matching this app's established accessibility rule — see
/// Notifications' own priority-badge doc comment for the same posture).
class TutorMessageBubble extends StatelessWidget {
  const TutorMessageBubble({super.key, required this.message});

  final TutorMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final isUser = message.isFromUser;
    final roleLabel = isUser
        ? l10n.aiTutorMessageFromUser
        : l10n.aiTutorMessageFromAssistant;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Semantics(
        label: '$roleLabel: ${message.content}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: MadeenSpace.xxs),
            padding: const EdgeInsets.symmetric(
              horizontal: MadeenSpace.sm + 2,
              vertical: MadeenSpace.sm - 2,
            ),
            decoration: BoxDecoration(
              color: isUser ? t.primaryAction : t.surface,
              borderRadius: BorderRadius.circular(MadeenRadius.card),
              border: isUser ? null : Border.all(color: t.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.content,
                  style: MadeenType.bodyMd.copyWith(
                    color: isUser ? t.onPrimaryAction : t.ink,
                  ),
                ),
                const SizedBox(height: MadeenSpace.xxs),
                Text(
                  formatTutorMessageTime(context, message.timestamp),
                  style: MadeenType.labelSm.copyWith(
                    color: isUser
                        ? t.onPrimaryAction.withValues(alpha: 0.7)
                        : t.inkTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
