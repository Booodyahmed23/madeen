# auth

Registration, login, token refresh/rotation, logout, forgot/reset password,
profile editing, change password and account deletion — all against the
**real** API (docs/MOBILE_API_CONTRACT.md §A1). Nothing in this feature is
mocked.

- `domain/` — `AuthUser`, `AuthSession`, and the `AuthRepository` interface.
  No Flutter or Dio imports here — this layer is plain Dart.
- `data/` — `AuthRemoteDataSource` (the only place that knows `/auth/*` and
  `/users/me`'s JSON shapes) and `AuthRepositoryImpl` (maps errors onto
  `AppFailure`, persists the refresh token via `SecureStorage`).
- `presentation/` — `AuthState`, `AuthNotifier`, the screens (Login,
  Register, Forgot Password, Reset Password, Profile, Change Password,
  Delete Account, Session Unavailable),
  form validators, and shared widgets (error banner, password field,
  logout confirmation).

## Session lifecycle

- **States:** `Initializing` → `Authenticated` | `Unauthenticated` |
  `SessionUnavailable`. The last one means a refresh token is stored but
  the server couldn't be reached to restore it (offline, 5xx, 429): the
  token is **kept**, and the user chooses Try again or Log out. Only a 4xx
  verdict on the token itself (expired/revoked/reused/malformed) clears it.
- **Tokens:** the API returns only `{ accessToken }` in the body; the
  refresh token arrives as a `Set-Cookie: refresh_token=…` header, which
  the data source reads by hand (`ApiClient.postWithHeaders`) and sends
  back as a `Cookie` header on refresh and logout. It lives in
  Keychain/Keystore (`SecureStorage`); the access token lives only in
  memory (`AuthState`). Login, register and session restore return no
  user, so they are followed by `GET /auth/me` with the new token.
- **401 handling:** `core/network/AuthInterceptor` refreshes once and
  retries once; concurrent 401s share one in-flight refresh (the backend
  treats a second use of a rotated refresh token as replay and revokes the
  whole session family). Only login, register, refresh, logout and
  password reset are never retried; `/auth/me` and `/auth/change-password`
  are. A silent refresh only swaps the access token — it doesn't reload
  the user.
- **Logout:** local session cleared first, server revocation best-effort.
- **Change password:** keeps this device signed in with the returned
  tokens; the server signs out every other device.
- **Delete account:** `DELETE /users/me` with the password. On success the
  local session and the device's per-user data (`localUserDataWipersProvider`,
  wired in `main.dart`) are wiped and the app returns to Login. No logout
  call follows — the server has already ended every session.
- **Reset password:** revokes every session, so the stored session is
  cleared and the user logs in again.

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

Uses `POST /auth/password-reset/request` and `/confirm`. Reset emails are
not sent yet, so the flow can't be completed end to end for now. The
backend emails a link to the **web app** (`WEB_APP_URL/reset-password
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
| Change email | `UpdateProfileDto` excludes email; no re-verification flow |
| Email verification | No model or endpoint |
| Avatar | No field, upload, or storage |
| Session / device management | `RefreshSession` stores user agent/IP, but no list/revoke endpoint |
