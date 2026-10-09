import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/device_session.dart';
import '../widgets/device_name.dart';
import '../widgets/logout_confirmation.dart';

/// Every device signed in to the account (`GET /auth/sessions`), with a way
/// to sign one out or all the others (contract §A1). Signing out "this
/// device" is logging out. Reloaded after each change: a session's id
/// changes whenever its device refreshes, so ids are never reused.
final deviceSessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((
  ref,
) async {
  final result = await ref.watch(authRepositoryProvider).getDeviceSessions();
  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
});

class SignedInDevicesScreen extends ConsumerStatefulWidget {
  const SignedInDevicesScreen({super.key});

  @override
  ConsumerState<SignedInDevicesScreen> createState() =>
      _SignedInDevicesScreenState();
}

class _SignedInDevicesScreenState extends ConsumerState<SignedInDevicesScreen> {
  bool _isBusy = false;

  Future<bool> _confirm(String title, String message, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.authCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _run(Future<Result<Object?>> Function() action) async {
    setState(() => _isBusy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);
    ref.invalidate(deviceSessionsProvider);
    final l10n = AppLocalizations.of(context)!;
    final message = switch (result) {
      Success(value: final int count) => l10n.devicesSignedOutCount(count),
      Success() => null,
      Failure(:final failure) => localizedFailureMessage(l10n, failure),
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _signOut(DeviceSession session) async {
    if (session.isCurrent) {
      await confirmAndLogout(context, ref);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (!await _confirm(
      l10n.devicesSignOutConfirmTitle,
      l10n.devicesSignOutConfirmMessage(
        deviceNameFromUserAgent(session.userAgent),
      ),
      l10n.devicesSignOut,
    )) {
      return;
    }
    await _run(
      () => ref.read(authRepositoryProvider).signOutDevice(session.id),
    );
  }

  Future<void> _signOutOthers() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _confirm(
      l10n.devicesSignOutAllConfirmTitle,
      l10n.devicesSignOutAllConfirmMessage,
      l10n.devicesSignOut,
    )) {
      return;
    }
    await _run(() => ref.read(authRepositoryProvider).signOutOtherDevices());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final sessions = ref.watch(deviceSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.devicesTitle),
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: switch (sessions) {
          AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.refresh(deviceSessionsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                MadeenSpace.pageMargin,
                MadeenSpace.lg,
                MadeenSpace.pageMargin,
                MadeenSpace.xl,
              ),
              children: [
                Text(
                  l10n.devicesIntro,
                  style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
                ),
                const SizedBox(height: MadeenSpace.md),
                MadeenCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MadeenSpace.md,
                  ),
                  child: MadeenDividedList(
                    children: [
                      for (final session in value)
                        _DeviceRow(
                          session: session,
                          onSignOut: _isBusy ? null : () => _signOut(session),
                        ),
                    ],
                  ),
                ),
                if (value.any((s) => !s.isCurrent)) ...[
                  const SizedBox(height: MadeenSpace.lg),
                  OutlinedButton(
                    onPressed: _isBusy ? null : _signOutOthers,
                    child: Text(l10n.devicesSignOutAll),
                  ),
                ],
              ],
            ),
          ),
          AsyncError(:final error) => MadeenErrorState(
            message: error is AppFailure
                ? localizedFailureMessage(l10n, error)
                : l10n.errorUnknown,
            retryLabel: l10n.authRetry,
            onRetry: () => ref.invalidate(deviceSessionsProvider),
          ),
          _ => const Center(child: MadeenLoadingState()),
        },
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.session, required this.onSignOut});

  final DeviceSession session;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lastActive = DateFormat.yMMMd(locale)
        .add_jm()
        .format(session.lastActiveAt.toLocal());
    final name = deviceNameFromUserAgent(session.userAgent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MadeenSpace.sm),
      child: Row(
        children: [
          Icon(
            name.contains('iPhone') || name.contains('Android')
                ? Icons.smartphone_outlined
                : Icons.computer_outlined,
            color: t.inkSecondary,
          ),
          const SizedBox(width: MadeenSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: MadeenType.bodyMd.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: MadeenSpace.xxs),
                Text(
                  session.isCurrent
                      ? l10n.devicesThisDevice
                      : l10n.devicesLastActive(lastActive),
                  style: MadeenType.bodySm.copyWith(
                    color: session.isCurrent ? t.success : t.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSignOut,
            child: Text(
              session.isCurrent ? l10n.navLogout : l10n.devicesSignOut,
            ),
          ),
        ],
      ),
    );
  }
}
