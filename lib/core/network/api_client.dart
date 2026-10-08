import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'auth_session_callbacks.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
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

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) parse,
  }) => _send(() => _dio.get(path, queryParameters: queryParameters), parse);

  Future<T> post<T>(
    String path, {
    Object? data,
    required T Function(dynamic data) parse,
  }) => _send(() => _dio.post(path, data: data), parse);

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
    final message = body is Map<String, dynamic>
        ? (body['message'] is List
              ? (body['message'] as List).join(', ')
              : body['message']?.toString())
        : null;

    return ApiException(
      statusCode: response.statusCode ?? 0,
      message: message ?? 'Something went wrong.',
      requestId: body is Map<String, dynamic>
          ? body['requestId'] as String?
          : null,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
