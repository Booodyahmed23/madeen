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
        'message': 'An account with this email already exists',
        'requestId': 'req-1',
      }),
    ).post('/auth/register', parse: (_) {});

    await expectLater(
      call,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.requestId, 'requestId', 'req-1')
            .having(
              (e) => e.message,
              'message',
              'An account with this email already exists',
            ),
      ),
    );
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
