import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The MADEEN wordmark lock-up for signed-out screens: the app name set in
/// the editorial serif, a short brass rule, and the product tagline. Purely
/// typographic — there is no logo asset.
///
/// The wordmark is always Latin ("MADEEN"), so its tracking is safe in RTL;
/// the tagline is localized and carries no tracking.
class MadeenBrandHeader extends StatelessWidget {
  const MadeenBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);

    return Semantics(
      header: true,
      label: '${l10n.appName}, ${l10n.homeTitle}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.appName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: MadeenType.serif,
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.2,
            ).copyWith(color: t.ink),
          ),
          const SizedBox(height: MadeenSpace.xs),
          Container(width: 32, height: 2, color: t.accent),
          const SizedBox(height: MadeenSpace.xs),
          Text(
            l10n.homeTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: t.inkSecondary),
          ),
        ],
      ),
    );
  }
}
