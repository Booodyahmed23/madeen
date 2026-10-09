import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

/// `POST /devices` and `POST /devices/unregister` (contract §A10).
class DevicesRemoteDataSource {
  DevicesRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// Registering again updates the same token; a token a previous account
  /// used on this phone moves to the current one.
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) => _apiClient.post(
    '/devices',
    data: {'token': token, 'platform': platform, 'locale': locale},
    parse: (_) {},
  );

  /// `204` even for an unknown token.
  Future<void> unregister(String token) => _apiClient.post(
    '/devices/unregister',
    data: {'token': token},
    parse: (_) {},
  );
}

final devicesRemoteDataSourceProvider = Provider<DevicesRemoteDataSource>(
  (ref) => DevicesRemoteDataSource(ref.watch(apiClientProvider)),
);
