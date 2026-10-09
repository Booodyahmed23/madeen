import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../localization/locale_provider.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'auth_session_callbacks.dart';
import 'language_interceptor.dart';

/// How this app names itself to the API — shown on the student's
/// "Signed-in devices" list (contract §A1), instead of Dart's default
/// `Dart/x.y (dart:io)`.
String appUserAgent() {
  if (kIsWeb) return 'MADEEN';
  return 'MADEEN (${Platform.operatingSystem}; '
      '${Platform.operatingSystemVersion})';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {if (!kIsWeb) 'User-Agent': appUserAgent()},
    ),
  );

  // `read`, not `watch`: a language change must not rebuild Dio (and drop
  // the auth interceptor's in-flight refresh); the header is read per request.
  dio.interceptors.add(
    LanguageInterceptor(() => apiLanguageCode(ref.read(localeProvider))),
  );

  // The real callbacks are attached at runtime by the auth feature (see
  // AuthSessionBridge) — this file never imports the auth feature
  // directly, per ARCHITECTURE.md §3/§31.11.
  dio.interceptors.add(
    AuthInterceptor(dio, ref.watch(authSessionBridgeProvider)),
  );

  if (!AppConfig.isProduction) {
    // No request headers: they carry the bearer access token, which must
    // not reach device logs even in dev/staging builds.
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseBody: false,
      ),
    );
  }

  return dio;
});

/// Thin wrapper around Dio that normalizes every failure into [ApiException],
/// matching the backend's error envelope. Feature repositories depend on
/// this instead of talking to Dio directly.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// [accessToken] overrides the session's token for this one request (and
  /// opts it out of refresh-and-retry) — for the profile fetch that follows
  /// login/register/refresh, before the new token is the session's.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? accessToken,
    required T Function(dynamic data) parse,
  }) => _send(
    () => _dio.get(
      path,
      queryParameters: queryParameters,
      options: accessToken == null
          ? null
          : Options(
              headers: {'Authorization': 'Bearer $accessToken'},
              extra: {explicitAuthKey: true},
            ),
    ),
    parse,
  );

  Future<T> post<T>(
    String path, {
    Object? data,
    required T Function(dynamic data) parse,
  }) => _send(() => _dio.post(path, data: data), parse);

  /// A POST whose parser also sees the response headers, and that can send
  /// extra request headers — for the auth calls that carry the refresh
  /// token in a `refresh_token` cookie rather than the body (contract §A1).
  Future<T> postWithHeaders<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
    required T Function(dynamic data, Headers headers) parse,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return parse(response.data, response.headers);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    required T Function(dynamic data) parse,
  }) => _send(() => _dio.patch(path, data: data), parse);

  Future<T> delete<T>(
    String path, {
    Object? data,
    required T Function(dynamic data) parse,
  }) => _send(() => _dio.delete(path, data: data), parse);

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(
        statusCode: 0,
        message: 'Could not reach the server. Check your connection.',
      );
    }

    final body = response.data;
    if (body is! Map<String, dynamic>) {
      return ApiException(
        statusCode: response.statusCode ?? 0,
        message: 'Something went wrong.',
      );
    }

    final rawMessage = body['message'];
    final message = rawMessage is List
        ? rawMessage.join(', ')
        : rawMessage?.toString();
    final details = body['details'];

    return ApiException(
      statusCode: response.statusCode ?? 0,
      message: message ?? 'Something went wrong.',
      code: body['code'] as String?,
      details: details is Map<String, dynamic> ? details : null,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
