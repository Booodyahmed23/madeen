import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Lesson Details' video area — **never a real player**. `Lesson.
/// videoAssetId` is an opaque reference with nothing real behind it yet
/// (see that field's own doc comment and COURSE_API_REQUIREMENTS.md's
/// "Video hosting status") — this renders an honest placeholder instead
/// of a fake "playing" state, so it never implies a video is actually
/// streaming.
class VideoPlaceholder extends StatelessWidget {
  const VideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);

    return Semantics(
      label: l10n.courseVideoPlaceholder,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        // A deep-slate media frame (the hero tokens) — reads as "the video
        // area" while plainly stating no video is available.
        child: Container(
          decoration: BoxDecoration(
            color: t.hero,
            borderRadius: BorderRadius.circular(MadeenRadius.card),
            border: Border.all(color: t.heroBorder),
          ),
          padding: const EdgeInsets.all(MadeenSpace.md),
          child: Center(
            // Scales down inside the fixed 16:9 frame at large text sizes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 44,
                    color: t.onHeroMuted,
                  ),
                  const SizedBox(height: MadeenSpace.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      l10n.courseVideoPlaceholder,
                      textAlign: TextAlign.center,
                      style: MadeenType.bodySm.copyWith(color: t.onHeroMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
