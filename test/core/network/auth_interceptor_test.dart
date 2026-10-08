import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/core/network/auth_session_callbacks.dart';

/// Answers each request through [handle] and records the Authorization
/// header every request actually went out with.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handle);

  final Future<int> Function(RequestOptions options) handle;
  final List<String?> sentAuthHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sentAuthHeaders.add(options.headers['Authorization'] as String?);
    final status = await handle(options);
    return ResponseBody.fromString(
      jsonEncode({'statusCode': status}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A minimal stand-in for the auth feature: an in-memory access token, a
/// scripted refresh, and counters for what the interceptor asked it to do.
class _Session {
  String? accessToken = 'old-token';
  int refreshCalls = 0;
  int expiredCalls = 0;
  Future<String?> Function() onRefresh = () async => 'new-token';

  AuthSessionBridge get bridge => AuthSessionBridge()
    ..attach(
      AuthSessionCallbacks(
        getAccessToken: () => accessToken,
        refreshAccessToken: () async {
          refreshCalls++;
          final token = await onRefresh();
          if (token != null) accessToken = token;
          return token;
        },
        onSessionExpired: () {
          expiredCalls++;
          accessToken = null;
        },
      ),
    );
}

void main() {
  late _Session session;

  Dio buildDio(_FakeAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio, session.bridge));
    return dio;
  }

  /// 401 for anything not carrying the refreshed token, 200 otherwise.
  Future<int> acceptsOnlyNewToken(RequestOptions options) async =>
      options.headers['Authorization'] == 'Bearer new-token' ? 200 : 401;

  setUp(() => session = _Session());

  test('attaches the current access token as a Bearer header', () async {
    final adapter = _FakeAdapter((_) async => 200);
    await buildDio(adapter).get<dynamic>('/users/me');

    expect(adapter.sentAuthHeaders, ['Bearer old-token']);
  });

  test('sends no Authorization header when signed out', () async {
    session.accessToken = null;
    final adapter = _FakeAdapter((_) async => 200);
    await buildDio(adapter).get<dynamic>('/users/me');

    expect(adapter.sentAuthHeaders, [null]);
  });

  test(
    '401 -> refresh -> retries the request once with the new token',
    () async {
      final adapter = _FakeAdapter(acceptsOnlyNewToken);

      final response = await buildDio(adapter).get<dynamic>('/users/me');

      expect(response.statusCode, 200);
      expect(session.refreshCalls, 1);
      expect(adapter.sentAuthHeaders, ['Bearer old-token', 'Bearer new-token']);
    },
  );

  test('retries at most once: a second 401 is returned, not looped', () async {
    final adapter = _FakeAdapter((_) async => 401);

    await expectLater(
      buildDio(adapter).get<dynamic>('/users/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(session.refreshCalls, 1);
    expect(adapter.sentAuthHeaders, hasLength(2));
  });

  test('concurrent 401s share a single in-flight refresh', () async {
    final refreshGate = Completer<String?>();
    session.onRefresh = () => refreshGate.future;
    final adapter = _FakeAdapter(acceptsOnlyNewToken);
    final dio = buildDio(adapter);

    final requests = [
      dio.get<dynamic>('/users/me'),
      dio.get<dynamic>('/courses'),
      dio.get<dynamic>('/performance'),
    ];
    // Let all three hit 401 and queue on the same refresh.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    refreshGate.complete('new-token');
    final responses = await Future.wait(requests);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    // Rotating refresh tokens: a second parallel refresh would replay an
    // already-rotated token and get the whole session revoked.
    expect(session.refreshCalls, 1);
  });

  test('a 401 for a request sent with a since-replaced token retries with the '
      'current token without refreshing again', () async {
    final adapter = _FakeAdapter((options) async {
      if (options.headers['Authorization'] == 'Bearer old-token') {
        // Another request's refresh completes while this one is in
        // flight with the old token.
        session.accessToken = 'new-token';
        return 401;
      }
      return 200;
    });

    final response = await buildDio(adapter).get<dynamic>('/users/me');

    expect(response.statusCode, 200);
    expect(adapter.sentAuthHeaders, ['Bearer old-token', 'Bearer new-token']);
    expect(session.refreshCalls, 0);
  });

  test(
    'expired refresh token -> session expired, original 401 surfaces',
    () async {
      session.onRefresh = () async => null;
      final adapter = _FakeAdapter((_) async => 401);

      await expectLater(
        buildDio(adapter).get<dynamic>('/users/me'),
        throwsA(isA<DioException>()),
      );
      expect(session.expiredCalls, 1);
      expect(session.accessToken, isNull);
      expect(adapter.sentAuthHeaders, hasLength(1), reason: 'no retry');
    },
  );

  test('a refresh that cannot complete (offline) fails the request but keeps '
      'the session', () async {
    session.onRefresh = () async => throw const NetworkFailure();
    final adapter = _FakeAdapter((_) async => 401);

    await expectLater(
      buildDio(adapter).get<dynamic>('/users/me'),
      throwsA(isA<DioException>()),
    );
    expect(session.expiredCalls, 0);
    expect(session.accessToken, 'old-token');
  });

  for (final path in [
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/logout',
    '/auth/password-reset/request',
    '/auth/password-reset/confirm',
  ]) {
    test('never refreshes for $path (prevents refresh loops)', () async {
      final adapter = _FakeAdapter((_) async => 401);

      await expectLater(
        buildDio(adapter).post<dynamic>(path),
        throwsA(isA<DioException>()),
      );
      expect(session.refreshCalls, 0);
    });
  }

  for (final path in ['/auth/me', '/auth/change-password']) {
    test('refreshes and retries $path like any other call', () async {
      final adapter = _FakeAdapter(acceptsOnlyNewToken);

      final response = await buildDio(adapter).post<dynamic>(path);

      expect(response.statusCode, 200);
      expect(session.refreshCalls, 1);
    });
  }

  test('non-401 errors pass straight through', () async {
    final adapter = _FakeAdapter((_) async => 500);

    await expectLater(
      buildDio(adapter).get<dynamic>('/users/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
    expect(session.refreshCalls, 0);
  });
}
