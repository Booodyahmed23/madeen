import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';

/// Records each request and answers with [respond].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(
  int status,
  Object? body, {
  List<String> setCookie = const [],
}) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    if (setCookie.isNotEmpty) 'set-cookie': setCookie,
  },
);

const _cookie =
    'refresh_token=raw-refresh; Max-Age=604800; Path=/api/v1/auth; '
    'HttpOnly; Secure; SameSite=Lax';

void main() {
  late _Adapter adapter;

  AuthRemoteDataSource build(
    ResponseBody Function(RequestOptions options) respond,
  ) {
    adapter = _Adapter(respond);
    return AuthRemoteDataSource(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );
  }

  group('refreshTokenFromCookies', () {
    test('extracts the refresh_token value', () {
      expect(refreshTokenFromCookies([_cookie]), 'raw-refresh');
    });

    test('ignores other cookies and empty (clearing) values', () {
      expect(refreshTokenFromCookies(['other=1; Path=/']), isNull);
      expect(refreshTokenFromCookies(['refresh_token=; Max-Age=0']), isNull);
      expect(refreshTokenFromCookies(null), isNull);
    });
  });

  test('login reads the access token from the body and the refresh token '
      'from the cookie', () async {
    final source = build(
      (_) => _json(200, {'accessToken': 'access-1'}, setCookie: [_cookie]),
    );

    final tokens = await source.login(email: 'a@b.co', password: 'p');

    expect(tokens.accessToken, 'access-1');
    expect(tokens.refreshToken, 'raw-refresh');
    expect(adapter.requests.single.path, '/auth/login');
  });

  test('a token response without the cookie fails instead of starting a '
      'session that cannot be refreshed', () async {
    final source = build((_) => _json(200, {'accessToken': 'access-1'}));

    await expectLater(
      source.login(email: 'a@b.co', password: 'p'),
      throwsA(isA<ApiException>()),
    );
  });

  test('refresh sends the token as a cookie with no body', () async {
    final source = build(
      (_) => _json(200, {'accessToken': 'access-2'}, setCookie: [_cookie]),
    );

    await source.refresh('stored');

    final request = adapter.requests.single;
    expect(request.path, '/auth/refresh');
    expect(request.headers['Cookie'], 'refresh_token=stored');
    expect(request.data, isNull);
  });

  test('logout sends the token as a cookie with no body', () async {
    final source = build((_) => _json(204, null));

    await source.logout('stored');

    final request = adapter.requests.single;
    expect(request.path, '/auth/logout');
    expect(request.headers['Cookie'], 'refresh_token=stored');
    expect(request.data, isNull);
  });

  test('the profile comes from /auth/me, with an explicit token', () async {
    final source = build(
      (_) => _json(200, {
        'id': 'u1',
        'email': 'a@b.co',
        'firstName': 'A',
        'lastName': 'B',
        'role': 'USER',
      }),
    );

    final user = await source.getCurrentUser(accessToken: 'fresh');

    final request = adapter.requests.single;
    expect(request.path, '/auth/me');
    expect(request.headers['Authorization'], 'Bearer fresh');
    expect(user.role, 'USER');
  });

  test('password reset uses the password-reset endpoints', () async {
    final source = build((_) => _json(200, {'message': 'ok'}));

    await source.requestPasswordReset('a@b.co');
    await source.confirmPasswordReset(token: 't', newPassword: 'n');

    expect(adapter.requests.map((r) => r.path), [
      '/auth/password-reset/request',
      '/auth/password-reset/confirm',
    ]);
  });

  test('delete account sends DELETE /users/me with the password', () async {
    final source = build((_) => _json(204, null));

    await source.deleteAccount('secret');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/users/me');
    expect(request.data, {'password': 'secret'});
  });
}
