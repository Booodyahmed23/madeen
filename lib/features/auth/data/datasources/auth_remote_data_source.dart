import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

/// Raw shape of a register/login/refresh response — this is the only place
/// in the app that knows the backend's exact JSON keys for these calls.
class AuthResponseModel {
  const AuthResponseModel({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthResponseModel(
      userId: user['id'] as String,
      email: user['email'] as String,
      firstName: user['firstName'] as String,
      lastName: user['lastName'] as String,
      roles: (user['roles'] as List).cast<String>(),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;
  final String accessToken;
  final String refreshToken;
}

class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      roles: (json['roles'] as List).cast<String>(),
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;
}

/// Talks to `/auth/*` and `/users/me` — the only layer in the app that
/// knows these paths and JSON shapes. AuthRepositoryImpl depends on this,
/// never on ApiClient directly.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthResponseModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _apiClient.post(
      '/auth/register',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
      },
      parse: (data) => AuthResponseModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) {
    return _apiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      parse: (data) => AuthResponseModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<AuthResponseModel> refresh(String refreshToken) {
    return _apiClient.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      parse: (data) => AuthResponseModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> logout(String? refreshToken) {
    return _apiClient.post(
      '/auth/logout',
      data: {'refreshToken': ?refreshToken},
      parse: (_) {},
    );
  }

  Future<void> forgotPassword(String email) {
    return _apiClient.post(
      '/auth/forgot-password',
      data: {'email': email},
      parse: (_) {},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _apiClient.post(
      '/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
      parse: (_) {},
    );
  }

  /// `/users/me` rather than the equivalent `/auth/me`: the network layer
  /// never refresh-and-retries `/auth/*` paths (see AuthInterceptor), and a
  /// profile load must survive an expired access token like any other call.
  Future<UserProfileModel> getCurrentUser() {
    return _apiClient.get(
      '/users/me',
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
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});
