import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

/// A tiny in-memory stand-in for the backend's Identity endpoints, keyed by
/// path — just enough of the real contract (see backend auth.controller.ts)
/// to drive the app's *real* provider graph end to end.
class _FakeBackend implements HttpClientAdapter {
  final List<String> calls = [];
  var acceptedAccessToken = 'access-1';
  var refreshCount = 0;

  static const _me = {
    'id': 'user-1',
    'email': 'jane@example.com',
    'firstName': 'Jane',
    'lastName': 'Doe',
    'role': 'USER',
  };

  /// Token responses carry only the access token in the body; the refresh
  /// token travels in a `Set-Cookie` header (contract §A1).
  (int, Object, String?) _tokens(String access, String refresh) => (
    200,
    {'accessToken': access},
    'refresh_token=$refresh; Path=/api/v1/auth; HttpOnly',
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    calls.add('${options.method} $path');
    final auth = options.headers['Authorization'];

    final (int status, Object body, String? cookie) = switch (path) {
      '/auth/login' => _tokens('access-1', 'refresh-1'),
      '/auth/refresh' => () {
        refreshCount++;
        acceptedAccessToken = 'access-${refreshCount + 1}';
        return _tokens(acceptedAccessToken, 'refresh-2');
      }(),
      '/auth/me' when auth == 'Bearer $acceptedAccessToken' => (200, _me, null),
      _ => (
        401,
        {'statusCode': 401, 'message': 'Invalid or expired token'},
        null,
      ),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'set-cookie': ?(cookie == null ? null : [cookie]),
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockSecureStorage storage;
  late _FakeBackend backend;
  late ProviderContainer container;
  String? storedRefreshToken;

  setUp(() async {
    storedRefreshToken = null;
    storage = MockSecureStorage();
    when(() => storage.readRefreshToken())
        .thenAnswer((_) async => storedRefreshToken);
    when(() => storage.saveRefreshToken(any())).thenAnswer((invocation) async {
      storedRefreshToken = invocation.positionalArguments.first as String;
    });
    when(() => storage.clear()).thenAnswer((_) async {
      storedRefreshToken = null;
    });

    backend = _FakeBackend();
    container = ProviderContainer(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = backend;

    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'login runs through the real provider graph without a dependency cycle '
    '(regression: CircularDependencyError on every real auth request)',
    () async {
      final result = await container
          .read(authNotifierProvider.notifier)
          .login(email: 'jane@example.com', password: 'Password123');

      expect(result, isA<Success<dynamic>>());
      expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
      expect(storedRefreshToken, 'refresh-1');
    },
  );

  test('authenticated requests carry the session access token', () async {
    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'jane@example.com', password: 'Password123');

    final user = await container
        .read(authNotifierProvider.notifier)
        .refreshCurrentUser();

    expect(user, isA<Success<dynamic>>());
    expect(backend.refreshCount, 0);
  });

  test('an expired access token is refreshed through the real notifier and the '
      'request retried', () async {
    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'jane@example.com', password: 'Password123');
    // The server stops accepting the current access token.
    backend.acceptedAccessToken = 'rotated-out';

    final user = await container
        .read(authNotifierProvider.notifier)
        .refreshCurrentUser();

    expect(user, isA<Success<dynamic>>());
    expect(backend.refreshCount, 1);
    expect(backend.calls, [
      'POST /auth/login',
      'GET /auth/me',
      'GET /auth/me',
      'POST /auth/refresh',
      'GET /auth/me',
    ]);
    final state = container.read(authNotifierProvider) as AuthAuthenticated;
    expect(state.accessToken, 'access-2');
    expect(storedRefreshToken, 'refresh-2');
  });
}
