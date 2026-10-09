import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/auth_session_callbacks.dart';
import '../../../../core/session/sign_out_hooks.dart';
import '../../../../core/storage/local_user_data.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Plugs this notifier into the network layer — see AuthSessionBridge
    // for why this is attached imperatively, not via a provider override.
    ref
        .read(authSessionBridgeProvider)
        .attach(
          AuthSessionCallbacks(
            getAccessToken: () => accessTokenOrNull,
            refreshAccessToken: silentRefresh,
            onSessionExpired: forceLogout,
          ),
        );
    // Deferred so _restore never assigns `state` while build() is still
    // running (which build's own return value would then overwrite).
    Future.microtask(_restore);
    return const AuthInitializing();
  }

  Future<void> _restore() async {
    try {
      final session = await _repository.restoreSession();
      state = session == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(
              user: session.user,
              accessToken: session.accessToken,
            );
    } on AppFailure catch (failure) {
      // The stored session is kept (see AuthRepository.restoreSession) —
      // the user chooses between retrying and signing out.
      state = AuthSessionUnavailable(failure);
    } catch (_) {
      // Secure storage itself failed (e.g. an unreadable keychain entry) —
      // there's no session this app can restore, so fall back to sign-in
      // rather than leaving the app on its startup spinner forever.
      state = const AuthUnauthenticated();
    }
  }

  /// Re-attempts session restoration from [AuthSessionUnavailable].
  Future<void> retryRestore() async {
    state = const AuthInitializing();
    await _restore();
  }

  Future<Result<AuthUser>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final result = await _repository.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    return result.when(
      success: (session) {
        state = AuthAuthenticated(
          user: session.user,
          accessToken: session.accessToken,
        );
        return Result.success(session.user);
      },
      failure: Result<AuthUser>.failure,
    );
  }

  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  }) async {
    final result = await _repository.login(email: email, password: password);
    return result.when(
      success: (session) {
        state = AuthAuthenticated(
          user: session.user,
          accessToken: session.accessToken,
        );
        return Result.success(session.user);
      },
      failure: Result<AuthUser>.failure,
    );
  }

  /// Signs out after the sign-out hooks (a few seconds at most — e.g.
  /// unregistering push while the session still works); the UI never waits
  /// on the server-side revocation, which the repository performs
  /// best-effort after clearing local storage.
  Future<void> logout() async {
    if (ref.read(signOutHooksProvider).isNotEmpty) await _runSignOutHooks();
    state = const AuthUnauthenticated();
    await _repository.logout();
  }

  /// Each hook gets a few seconds at most, and a failing one never blocks
  /// signing out.
  Future<void> _runSignOutHooks({bool cancelled = false}) async {
    for (final hook in ref.read(signOutHooksProvider)) {
      final run = cancelled ? hook.cancelled : hook.before;
      if (run == null) continue;
      try {
        await run().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Best-effort: the sign-out goes ahead regardless.
      }
    }
  }

  Future<Result<void>> forgotPassword(String email) {
    return _repository.forgotPassword(email);
  }

  /// On success every session is revoked server-side (this device's too),
  /// so a signed-in caller is signed out here as well.
  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final result = await _repository.resetPassword(
      token: token,
      newPassword: newPassword,
    );
    if (result is Success<void> && state is AuthAuthenticated) {
      state = const AuthUnauthenticated();
    }
    return result;
  }

  /// Keeps this device signed in with the new tokens; every other device is
  /// signed out by the server.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    switch (result) {
      case Success(value: final accessToken):
        final current = state;
        if (current is AuthAuthenticated) {
          state = current.copyWith(accessToken: accessToken);
        }
        return const Result.success(null);
      case Failure(:final failure):
        return Result.failure(failure);
    }
  }

  /// Deletes the account, wipes what the device keeps for this user, and
  /// signs out. No `/auth/logout` follows — the server already ended every
  /// session.
  Future<Result<void>> deleteAccount(String password) async {
    final current = state;
    await _runSignOutHooks();
    final result = await _repository.deleteAccount(password);
    if (result is Failure<void>) await _runSignOutHooks(cancelled: true);
    if (result is Success<void>) {
      if (current is AuthAuthenticated) {
        for (final wipe in ref.read(localUserDataWipersProvider)) {
          try {
            await wipe(current.user.id);
          } catch (_) {
            // Best-effort: the account is already gone server-side, and a
            // failed local wipe must not keep the user signed in.
          }
        }
      }
      state = const AuthUnauthenticated();
    }
    return result;
  }

  /// Re-fetches the signed-in user from the server (Profile calls this on
  /// open) so a name changed on another device isn't shown stale.
  Future<Result<AuthUser>> refreshCurrentUser() async {
    final result = await _repository.getCurrentUser();
    _applyUser(result);
    return result;
  }

  Future<Result<AuthUser>> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    final result = await _repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
    );
    _applyUser(result);
    return result;
  }

  void _applyUser(Result<AuthUser> result) {
    final current = state;
    if (result is Success<AuthUser> && current is AuthAuthenticated) {
      state = current.copyWith(user: result.value);
    }
  }

  /// Used only by [AuthInterceptor] (via [AuthSessionBridge]) to attach the current access token to outgoing
  /// requests — never called directly by UI code.
  String? get accessTokenOrNull {
    final current = state;
    return current is AuthAuthenticated ? current.accessToken : null;
  }

  /// Used only by [AuthInterceptor] to attempt a silent refresh when a
  /// request comes back 401. Updates local state on success; if the server
  /// rejected the session, drops to Unauthenticated without an extra
  /// network round trip (the interceptor already knows the session is dead
  /// — see ARCHITECTURE.md §31.11). Rethrows the [AppFailure] when the
  /// refresh couldn't be completed at all, leaving the session untouched.
  Future<String?> silentRefresh() async {
    final accessToken = await _repository.refreshAccessToken();
    if (accessToken == null) {
      state = const AuthUnauthenticated();
      return null;
    }
    final current = state;
    if (current is AuthAuthenticated) {
      state = current.copyWith(accessToken: accessToken);
    }
    return accessToken;
  }

  void forceLogout() {
    state = const AuthUnauthenticated();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
