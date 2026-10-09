import 'package:dio/dio.dart' show Headers;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/device_session.dart';

const _refreshCookieName = 'refresh_token';

/// What register, login, refresh and change-password return: the access
/// token from the body, and the (rotated) refresh token from the
/// `Set-Cookie: refresh_token=…` header — the API never puts the refresh
/// token in the body, and returns no user (contract §A1).
class AuthTokensModel {
  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokensModel.fromResponse(dynamic data, Headers headers) {
    final refreshToken = refreshTokenFromCookies(headers['set-cookie']);
    if (refreshToken == null) {
      // A session without a refresh token would silently end at the first
      // access-token expiry — fail now instead.
      throw const ApiException(
        statusCode: 500,
        message: 'The server did not return a refresh_token cookie.',
      );
    }
    return AuthTokensModel(
      accessToken: (data as Map<String, dynamic>)['accessToken'] as String,
      refreshToken: refreshToken,
    );
  }

  final String accessToken;
  final String refreshToken;
}

/// The `refresh_token` value from a response's `set-cookie` headers, or
/// `null` when there is none (or it is being cleared with an empty value).
String? refreshTokenFromCookies(List<String>? setCookieHeaders) {
  for (final header in setCookieHeaders ?? const <String>[]) {
    final pair = header.split(';').first.trim();
    final separator = pair.indexOf('=');
    if (separator < 0) continue;
    if (pair.substring(0, separator).trim() != _refreshCookieName) continue;
    final value = pair.substring(separator + 1).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

Map<String, String> _refreshCookieHeader(String refreshToken) => {
  'Cookie': '$_refreshCookieName=$refreshToken',
};

/// `GET /auth/me` (`{ id, email, firstName, lastName, role }`) and
/// `PATCH /users/me` (the same plus `isActive`, `createdAt`, `updatedAt`,
/// which the app doesn't use).
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      role: json['role'] as String,
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// `USER` | `ADMIN`.
  final String role;
}

/// Talks to `/auth/*` and `/users/me` — the only layer in the app that
/// knows these paths and JSON shapes. AuthRepositoryImpl depends on this,
/// never on ApiClient directly.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthTokensModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _apiClient.postWithHeaders(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
      },
      parse: AuthTokensModel.fromResponse,
    );
  }

  Future<AuthTokensModel> login({
    required String email,
    required String password,
  }) {
    return _apiClient.postWithHeaders(
      '/auth/login',
      data: {'email': email, 'password': password},
      parse: AuthTokensModel.fromResponse,
    );
  }

  /// Rotates the refresh token: the returned [AuthTokensModel.refreshToken]
  /// replaces [refreshToken], which the server has now revoked.
  Future<AuthTokensModel> refresh(String refreshToken) {
    return _apiClient.postWithHeaders(
      '/auth/refresh',
      headers: _refreshCookieHeader(refreshToken),
      parse: AuthTokensModel.fromResponse,
    );
  }

  Future<void> logout(String refreshToken) {
    return _apiClient.postWithHeaders(
      '/auth/logout',
      headers: _refreshCookieHeader(refreshToken),
      parse: (_, _) {},
    );
  }

  Future<void> requestPasswordReset(String email) {
    return _apiClient.post(
      '/auth/password-reset/request',
      data: {'email': email},
      parse: (_) {},
    );
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) {
    return _apiClient.post(
      '/auth/password-reset/confirm',
      data: {'token': token, 'newPassword': newPassword},
      parse: (_) {},
    );
  }

  /// Signs out every other device: the returned tokens replace the current
  /// ones (the old refresh token is revoked).
  Future<AuthTokensModel> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _apiClient.postWithHeaders(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      parse: AuthTokensModel.fromResponse,
    );
  }

  /// [accessToken] authenticates this one call explicitly — used right after
  /// login/register/refresh, before the new token is in the app's session.
  Future<UserProfileModel> getCurrentUser({String? accessToken}) {
    return _apiClient.get(
      '/auth/me',
      accessToken: accessToken,
      parse: (data) => UserProfileModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<UserProfileModel> updateProfile({
    String? firstName,
    String? lastName,
  }) {
    return _apiClient.patch(
      '/users/me',
      data: {'firstName': ?firstName, 'lastName': ?lastName},
      parse: (data) => UserProfileModel.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Anonymises and deactivates the account; every session (including the
  /// current access token) ends at once.
  Future<void> deleteAccount(String password) {
    return _apiClient.delete(
      '/users/me',
      data: {'password': password},
      parse: (_) {},
    );
  }

  /// `GET /auth/sessions` — every device signed in, most recent first.
  Future<List<DeviceSession>> listSessions() => _apiClient.get(
    '/auth/sessions',
    parse: (data) => [
      for (final json in data as List)
        _sessionFromJson(json as Map<String, dynamic>),
    ],
  );

  /// `DELETE /auth/sessions/:id` — that device is signed out at once.
  Future<void> revokeSession(String sessionId) =>
      _apiClient.delete('/auth/sessions/$sessionId', parse: (_) {});

  /// `POST /auth/sessions/revoke-others` — returns how many were signed out.
  Future<int> revokeOtherSessions() => _apiClient.post(
    '/auth/sessions/revoke-others',
    parse: (data) => ((data as Map<String, dynamic>)['revoked'] as num).toInt(),
  );
}

DeviceSession _sessionFromJson(Map<String, dynamic> json) => DeviceSession(
  id: json['id'] as String,
  userAgent: json['userAgent'] as String? ?? '',
  ipAddress: json['ipAddress'] as String?,
  lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
  isCurrent: json['current'] as bool? ?? false,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});
