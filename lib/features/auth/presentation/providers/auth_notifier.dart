import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/auth_session_callbacks.dart';
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

  /// Signs out immediately — the UI never waits on the server-side
  /// revocation, which the repository performs best-effort after clearing
  /// local storage.
  Future<void> logout() async {
    state = const AuthUnauthenticated();
    await _repository.logout();
  }

  Future<Result<void>> forgotPassword(String email) {
    return _repository.forgotPassword(email);
  }

  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _repository.resetPassword(token: token, newPassword: newPassword);
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
    final session = await _repository.restoreSession();
    if (session == null) {
      state = const AuthUnauthenticated();
      return null;
    }
    state = AuthAuthenticated(
      user: session.user,
      accessToken: session.accessToken,
    );
    return session.accessToken;
  }

  void forceLogout() {
    state = const AuthUnauthenticated();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
