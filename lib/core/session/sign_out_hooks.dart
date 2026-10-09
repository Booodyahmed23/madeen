import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Work that must happen while the session is still valid, right before it
/// ends — e.g. unregistering this device's push token, which the API only
/// accepts with the user's access token (contract §A10).
class SignOutHook {
  const SignOutHook({required this.before, this.cancelled});

  /// Runs before logout and before account deletion.
  final Future<void> Function() before;

  /// Runs when the sign-out didn't happen after all (account deletion
  /// refused, e.g. a wrong password) — undo [before].
  final Future<void> Function()? cancelled;
}

/// Empty here so `core/` and the auth feature never import the features
/// that need these hooks; the composition root (main.dart) overrides it
/// (app/sign_out_hooks.dart).
final signOutHooksProvider = Provider<List<SignOutHook>>((ref) => const []);
