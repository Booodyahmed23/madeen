import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_state.dart';

/// Shown at startup for [AuthSessionUnavailable] — a stored session exists
/// but couldn't be confirmed with the server (offline, server error, rate
/// limited). Rendered by app/app.dart outside the router, like the
/// initializing spinner, since no route is meaningful until the session's
/// fate is known. Never discards the session on its own: only "Log out"
/// does.
class SessionUnavailableScreen extends ConsumerWidget {
  const SessionUnavailableScreen({super.key, required this.state});

  final AuthSessionUnavailable state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = MadeenTokens.of(context);
    final notifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MadeenSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MadeenBrandHeader(),
                  const SizedBox(height: MadeenSpace.xl),
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: t.inkSecondary,
                  ),
                  const SizedBox(height: MadeenSpace.md),
                  Text(
                    l10n.sessionUnavailableTitle,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.sessionUnavailableMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizedFailureMessage(l10n, state.failure),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: t.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: notifier.retryRestore,
                    child: Text(l10n.authRetry),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: notifier.logout,
                    child: Text(l10n.navLogout),
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
