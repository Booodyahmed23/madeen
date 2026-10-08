import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';

/// Shown where a study session or exam would start when the student has no
/// active plan (or the API answered 403 "no access") — explains why and
/// opens Plans (contract §G8/§A6).
class NoAccessNotice extends StatelessWidget {
  const NoAccessNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);

    return MadeenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: t.accentText),
              const SizedBox(width: MadeenSpace.xs),
              Expanded(
                child: Text(
                  l10n.noAccessTitle,
                  style: MadeenType.headlineSm.copyWith(color: t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: MadeenSpace.xs),
          Text(
            l10n.noAccessMessage,
            style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
          ),
          const SizedBox(height: MadeenSpace.md),
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.plans),
            child: Text(l10n.noAccessSeePlans),
          ),
        ],
      ),
    );
  }
}
