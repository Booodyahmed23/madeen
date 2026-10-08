import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function() respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond();

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ApiClient _client(Future<ResponseBody> Function() respond) =>
    ApiClient(Dio()..httpClientAdapter = _Adapter(respond));

void main() {
  test('parses a successful response', () async {
    final value = await _client(() async => _json(200, {'id': 'u1'}))
        .get('/users/me', parse: (data) => (data as Map)['id']);

    expect(value, 'u1');
  });

  test('maps the backend error envelope onto ApiException', () async {
    final call = _client(
      () async => _json(409, {
        'statusCode': 409,
        'error': 'Conflict',
        'message': 'An account with this email already exists',
        'path': '/api/v1/auth/register',
        'timestamp': '2026-10-08T00:00:00.000Z',
      }),
    ).post('/auth/register', parse: (_) {});

    await expectLater(
      call,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', isNull)
            .having(
              (e) => e.message,
              'message',
              'An account with this email already exists',
            ),
      ),
    );
  });

  test('carries the error code and details', () async {
    final call = _client(
      () async => _json(400, {
        'statusCode': 400,
        'error': 'Bad Request',
        'message': 'Reminder limit reached',
        'code': 'REMINDER_LIMIT_REACHED',
        'details': {'max': 20},
      }),
    ).post('/reminders', parse: (_) {});

    await expectLater(
      call,
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'REMINDER_LIMIT_REACHED')
            .having((e) => e.details, 'details', {'max': 20}),
      ),
    );
  });

  test('postWithHeaders exposes response headers and sends request headers',
      () async {
    RequestOptions? sent;
    final dio = Dio()
      ..httpClientAdapter = _Adapter(
        () async => ResponseBody.fromString(
          jsonEncode({'accessToken': 'a'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['refresh_token=r2; Path=/api/v1/auth; HttpOnly'],
          },
        ),
      );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sent = options;
          handler.next(options);
        },
      ),
    );

    final cookie = await ApiClient(dio).postWithHeaders(
      '/auth/refresh',
      headers: {'Cookie': 'refresh_token=r1'},
      parse: (_, headers) => headers['set-cookie']!.single,
    );

    expect(sent!.headers['Cookie'], 'refresh_token=r1');
    expect(cookie, startsWith('refresh_token=r2'));
  });

  test('joins class-validator message arrays', () async {
    final call = _client(
      () async => _json(400, {
        'message': ['email must be an email', 'password too short'],
      }),
    ).post('/auth/register', parse: (_) {});

    await expectLater(
      call,
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'email must be an email, password too short',
        ),
      ),
    );
  });

  test('no response at all (offline) becomes statusCode 0', () async {
    final call = _client(
      () async => throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/users/me'),
        reason: 'offline',
      ),
    ).get('/users/me', parse: (_) {});

    await expectLater(
      call,
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
    );
  });
}
