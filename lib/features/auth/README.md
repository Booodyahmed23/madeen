# auth

Registration, login, token refresh/rotation, logout, forgot/reset password,
and basic profile editing — all against the **real** backend `identity`
module (see docs/ARCHITECTURE.md §3). Nothing in this feature is mocked.

- `domain/` — `AuthUser`, `AuthSession`, and the `AuthRepository` interface.
  No Flutter or Dio imports here — this layer is plain Dart.
- `data/` — `AuthRemoteDataSource` (the only place that knows `/auth/*` and
  `/users/me`'s JSON shapes) and `AuthRepositoryImpl` (maps errors onto
  `AppFailure`, persists the refresh token via `SecureStorage`).
- `presentation/` — `AuthState`, `AuthNotifier`, the screens (Login,
  Register, Forgot Password, Reset Password, Profile, Session Unavailable),
  form validators, and shared widgets (error banner, password field,
  logout confirmation).

## Session lifecycle

- **States:** `Initializing` → `Authenticated` | `Unauthenticated` |
  `SessionUnavailable`. The last one means a refresh token is stored but
  the server couldn't be reached to restore it (offline, 5xx, 429): the
  token is **kept**, and the user chooses Try again or Log out. Only a 4xx
  verdict on the token itself (expired/revoked/reused/malformed) clears it.
- **Tokens:** the refresh token lives in Keychain/Keystore
  (`SecureStorage`); the access token lives only in memory (`AuthState`).
- **401 handling:** `core/network/AuthInterceptor` refreshes once and
  retries once; concurrent 401s share one in-flight refresh (the backend
  treats a second use of a rotated refresh token as replay and revokes the
  whole session family). `/auth/*` requests are never retried.
- **Logout:** local session cleared first, server revocation best-effort.

The network layer reaches this feature only through `AuthSessionBridge`
(`core/network/auth_session_callbacks.dart`), which `AuthNotifier` attaches
itself to at build time. It is deliberately not a provider override that
reads `authNotifierProvider`: the notifier depends on Dio, so that would be
a dependency cycle (Riverpod `CircularDependencyError` on every real
request — see `test/features/auth/auth_wiring_test.dart`).

Other features depend on auth only through `core/` or by reading
`authNotifierProvider`'s state — never by importing this folder's `data/` or
`domain/` internals directly.

## Password reset on mobile

The backend emails a link to the **web app** (`WEB_APP_URL/reset-password
?token=…`); no native deep link is configured. On mobile, Forgot Password →
"Already have a reset code? Enter code" opens Reset Password, where the
token from that link is pasted. `/reset-password?token=…` also prefills it,
ready for when deep links are configured. In development the backend's
console email provider prints the link instead of sending it.

## Backend-blocked account capabilities

The Identity module exposes no endpoints for these, so the app deliberately
offers **no UI** for them (no placeholders, no fake flows):

| Capability | Missing backend support |
|---|---|
| Change password (signed in) | No endpoint |
| Change email | `UpdateProfileDto` excludes email; no re-verification flow |
| Email verification | No model or endpoint |
| Avatar | No field, upload, or storage |
| Account deletion | No endpoint |
| Session / device management | `RefreshSession` stores user agent/IP, but no list/revoke endpoint |
