import '../../../../core/error/app_failure.dart';
import '../../domain/entities/auth_user.dart';

/// The states the whole app's navigation reacts to (router redirect logic
/// lives in core/router/app_router.dart) — ARCHITECTURE.md's Phase 2
/// instructions are explicit that the app must distinguish initializing
/// (checking for a restorable session), unauthenticated, and
/// authenticated. [AuthSessionUnavailable] is the fourth, startup-only
/// outcome: a session is stored but the server couldn't be reached to
/// restore it — see app/app.dart.
sealed class AuthState {
  const AuthState();
}

class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// A refresh token is stored, but restoring it failed for a reason that
/// says nothing about the session itself (offline, server error, rate
/// limited). The token is kept; the user can retry or choose to sign out.
class AuthSessionUnavailable extends AuthState {
  const AuthSessionUnavailable(this.failure);

  final AppFailure failure;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user, required this.accessToken});

  final AuthUser user;
  final String accessToken;

  AuthAuthenticated copyWith({AuthUser? user, String? accessToken}) {
    return AuthAuthenticated(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
