import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../entities/device_session.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<Result<AuthSession>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  });

  /// Reads the persisted refresh token and, if present, attempts to obtain
  /// a fresh session — used on app startup to restore a signed-in session,
  /// and by the network layer's silent refresh.
  ///
  /// Returns `null` (not a [Result] failure) when there's no session to
  /// restore: either nothing is stored, or the server rejected the stored
  /// token (expired/revoked/reused) — in which case it is also cleared.
  ///
  /// Throws an `AppFailure` when the server couldn't be asked at all
  /// (offline, 5xx, rate limited). The stored token is **kept** in that
  /// case: a transient outage must never sign the user out.
  Future<AuthSession?> restoreSession();

  /// Exchanges the stored refresh token for a new access token, without
  /// re-fetching the user — used by the network layer's silent refresh.
  /// Same `null` / throws contract as [restoreSession].
  Future<String?> refreshAccessToken();

  /// Clears the local session first (so the user is signed out on this
  /// device no matter what), then makes a best-effort attempt to revoke the
  /// refresh session server-side.
  Future<void> logout();

  Future<Result<void>> forgotPassword(String email);

  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<Result<AuthUser>> getCurrentUser();

  Future<Result<AuthUser>> updateProfile({String? firstName, String? lastName});

  /// Changes the password and signs out every other device. Returns the new
  /// access token; the new refresh token is persisted (the old one is
  /// revoked).
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Permanently deletes (anonymises) the account. On success the server has
  /// already ended every session, and the local session is cleared — no
  /// logout call follows.
  Future<Result<void>> deleteAccount(String password);

  /// Devices where the student is signed in (contract §A1).
  Future<Result<List<DeviceSession>>> getDeviceSessions();

  /// Signs one other device out immediately.
  Future<Result<void>> signOutDevice(String sessionId);

  /// Signs every other device out; returns how many.
  Future<Result<int>> signOutOtherDevices();
}
