import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/device_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._secureStorage);

  final AuthRemoteDataSource _remote;
  final SecureStorage _secureStorage;

  @override
  Future<Result<AuthSession>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => _guard(() async {
    final tokens = await _remote.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    return _persistAndLoadUser(tokens);
  });

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) => _guard(() async {
    final tokens = await _remote.login(email: email, password: password);
    return _persistAndLoadUser(tokens);
  });

  @override
  Future<AuthSession?> restoreSession() async {
    final tokens = await _refreshStoredSession();
    if (tokens == null) return null;
    try {
      return await _loadUser(tokens.accessToken);
    } on ApiException catch (error) {
      // The refresh worked (and the rotated token is saved), so the session
      // is fine — only the profile couldn't be loaded right now.
      throw mapApiExceptionToFailure(error);
    }
  }

  @override
  Future<String?> refreshAccessToken() async {
    final tokens = await _refreshStoredSession();
    return tokens?.accessToken;
  }

  /// Exchanges the stored refresh token for new tokens and saves the rotated
  /// one. `null` when there's nothing stored or the server rejected it (the
  /// stored token is then cleared); throws an `AppFailure` when the server
  /// couldn't be asked at all, keeping the stored token.
  Future<AuthTokensModel?> _refreshStoredSession() async {
    final storedRefreshToken = await _secureStorage.readRefreshToken();
    if (storedRefreshToken == null) return null;

    try {
      final tokens = await _remote.refresh(storedRefreshToken);
      await _secureStorage.saveRefreshToken(tokens.refreshToken);
      return tokens;
    } on ApiException catch (error) {
      if (!_isSessionRejected(error)) {
        // Offline / server error / rate limited — the stored session may
        // be perfectly valid, so keep it and let the caller decide.
        throw mapApiExceptionToFailure(error);
      }
      // Stored refresh token is no longer usable (expired/revoked/reused) —
      // this is an expected "session over" outcome, not an error to surface.
      await _secureStorage.clear();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final storedRefreshToken = await _secureStorage.readRefreshToken();
    await _secureStorage.clear();
    if (storedRefreshToken == null) return;
    try {
      await _remote.logout(storedRefreshToken);
    } on ApiException {
      // Best-effort server-side revocation — the local session is already
      // cleared, so the user is signed out on this device regardless.
    }
  }

  /// A 4xx answer to a refresh is the server's verdict on the token itself
  /// (401 invalid/expired/revoked/reused, 400 missing). Everything else — no
  /// response (statusCode 0), 408, 429, 5xx — says nothing about the token.
  static bool _isSessionRejected(ApiException error) {
    final status = error.statusCode;
    return status >= 400 && status < 500 && status != 408 && status != 429;
  }

  @override
  Future<Result<void>> forgotPassword(String email) => _guard(() async {
    await _remote.requestPasswordReset(email);
  });

  @override
  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  }) => _guard(() async {
    await _remote.confirmPasswordReset(token: token, newPassword: newPassword);
    // The server revoked every session, this device's included.
    await _secureStorage.clear();
  });

  @override
  Future<Result<AuthUser>> getCurrentUser() => _guard(() async {
    final profile = await _remote.getCurrentUser();
    return _toAuthUser(profile);
  });

  @override
  Future<Result<AuthUser>> updateProfile({
    String? firstName,
    String? lastName,
  }) => _guard(() async {
    final profile = await _remote.updateProfile(
      firstName: firstName,
      lastName: lastName,
    );
    return _toAuthUser(profile);
  });

  @override
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {
    final tokens = await _remote.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _secureStorage.saveRefreshToken(tokens.refreshToken);
    return tokens.accessToken;
  });

  @override
  Future<Result<void>> deleteAccount(String password) => _guard(() async {
    await _remote.deleteAccount(password);
    await _secureStorage.clear();
  });

  @override
  Future<Result<List<DeviceSession>>> getDeviceSessions() =>
      _guard(_remote.listSessions);

  @override
  Future<Result<void>> signOutDevice(String sessionId) =>
      _guard(() => _remote.revokeSession(sessionId));

  @override
  Future<Result<int>> signOutOtherDevices() =>
      _guard(_remote.revokeOtherSessions);

  Future<AuthSession> _persistAndLoadUser(AuthTokensModel tokens) async {
    await _secureStorage.saveRefreshToken(tokens.refreshToken);
    return _loadUser(tokens.accessToken);
  }

  Future<AuthSession> _loadUser(String accessToken) async {
    final profile = await _remote.getCurrentUser(accessToken: accessToken);
    return AuthSession(user: _toAuthUser(profile), accessToken: accessToken);
  }

  AuthUser _toAuthUser(UserProfileModel profile) => AuthUser(
    id: profile.id,
    email: profile.email,
    firstName: profile.firstName,
    lastName: profile.lastName,
    role: profile.role,
  );

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(secureStorageProvider),
  );
});
