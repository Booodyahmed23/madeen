import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_notifier.dart';

/// Asks before signing out — every logout affordance (Home's app bar,
/// Profile) goes through this, so a stray tap never ends the session.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.logoutConfirmTitle),
      content: Text(l10n.logoutConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.authCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.navLogout),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await ref.read(authNotifierProvider.notifier).logout();
  }
}
