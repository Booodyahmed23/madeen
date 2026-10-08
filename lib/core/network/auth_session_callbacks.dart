import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shape of what a Dio client needs to stay authenticated (attach the
/// current access token, attempt a refresh on 401, react to a refresh that
/// fails) — described here with plain callbacks so `core/network` never has
/// to import the auth feature to use them. See ARCHITECTURE.md §31.11.
class AuthSessionCallbacks {
  const AuthSessionCallbacks({
    required this.getAccessToken,
    required this.refreshAccessToken,
    required this.onSessionExpired,
  });

  final String? Function() getAccessToken;

  /// Attempts a token refresh. Returns the new access token on success, or
  /// `null` if the server rejected the refresh (expired/invalid/reused
  /// refresh token) — the interceptor treats `null` as "give up, this
  /// session is over" rather than retrying further. Throws when the refresh
  /// couldn't be completed at all (offline, 5xx, rate limited): the session
  /// may still be valid, so the interceptor fails only the current request
  /// and does not end the session.
  final Future<String?> Function() refreshAccessToken;

  /// Called when a refresh attempt fails — the auth feature's implementation
  /// clears local session state so the UI drops back to "unauthenticated."
  final void Function() onSessionExpired;

  static final none = AuthSessionCallbacks(
    getAccessToken: () => null,
    refreshAccessToken: () async => null,
    onSessionExpired: () {},
  );
}

/// Where the auth feature plugs its [AuthSessionCallbacks] in at runtime
/// (`AuthNotifier.build` attaches itself), and where the Dio interceptor
/// reads them from on every request.
///
/// Deliberately a dependency-free holder rather than a provider override
/// that reads `authNotifierProvider`: the auth notifier itself depends on
/// Dio (notifier → repository → ApiClient → Dio), so a Dio-side provider
/// reading the notifier back is a dependency cycle — Riverpod rejects it
/// with a `CircularDependencyError` on the first real request.
class AuthSessionBridge {
  AuthSessionCallbacks _callbacks = AuthSessionCallbacks.none;

  AuthSessionCallbacks get callbacks => _callbacks;

  void attach(AuthSessionCallbacks callbacks) => _callbacks = callbacks;
}

final authSessionBridgeProvider = Provider<AuthSessionBridge>(
  (ref) => AuthSessionBridge(),
);
