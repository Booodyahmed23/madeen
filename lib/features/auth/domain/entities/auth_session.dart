import 'auth_user.dart';

/// What a successful register/login/refresh returns: a user plus a fresh
/// access token. The refresh token is deliberately not part of this
/// domain-level type — it never leaves the data layer's secure-storage
/// boundary once persisted (see SecureStorage / ARCHITECTURE.md §7).
class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final AuthUser user;
  final String accessToken;
}
