import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/auth_session.dart';
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
    final response = await _remote.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    return _persistAndMap(response);
  });

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _remote.login(email: email, password: password);
    return _persistAndMap(response);
  });

  @override
  Future<AuthSession?> restoreSession() async {
    final storedRefreshToken = await _secureStorage.readRefreshToken();
    if (storedRefreshToken == null) return null;

    try {
      final response = await _remote.refresh(storedRefreshToken);
      return await _persistAndMap(response);
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
    try {
      await _remote.logout(storedRefreshToken);
    } on ApiException {
      // Best-effort server-side revocation — the local session is already
      // cleared, so the user is signed out on this device regardless.
    }
  }

  /// A 4xx answer to a refresh is the server's verdict on the token itself
  /// (401 expired/revoked/reused, 400 malformed). Everything else — no
  /// response (statusCode 0), 408, 429, 5xx — says nothing about the token.
  static bool _isSessionRejected(ApiException error) {
    final status = error.statusCode;
    return status >= 400 && status < 500 && status != 408 && status != 429;
  }

  @override
  Future<Result<void>> forgotPassword(String email) => _guard(() async {
    await _remote.forgotPassword(email);
  });

  @override
  Future<Result<void>> resetPassword({
    required String token,
    required String newPassword,
  }) => _guard(() async {
    await _remote.resetPassword(token: token, newPassword: newPassword);
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

  Future<AuthSession> _persistAndMap(AuthResponseModel response) async {
    await _secureStorage.saveRefreshToken(response.refreshToken);
    return AuthSession(
      user: AuthUser(
        id: response.userId,
        email: response.email,
        firstName: response.firstName,
        lastName: response.lastName,
        roles: response.roles,
      ),
      accessToken: response.accessToken,
    );
  }

  AuthUser _toAuthUser(UserProfileModel profile) => AuthUser(
    id: profile.id,
    email: profile.email,
    firstName: profile.firstName,
    lastName: profile.lastName,
    roles: profile.roles,
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
