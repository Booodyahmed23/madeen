import 'package:dio/dio.dart';

import 'auth_session_callbacks.dart';

/// Auth endpoints whose 401 means "bad credentials / bad refresh token",
/// not "access token expired" — so they are never refresh-and-retried.
/// Every other path, including `/auth/me` and `/auth/change-password`,
/// refreshes and retries like any other call (contract §G5).
const _noRetryPaths = [
  '/auth/login',
  '/auth/register',
  '/auth/refresh',
  '/auth/logout',
  '/auth/password-reset/',
];
const _retriedKey = 'retried';

/// Request `extra` flag for a call that carries its own `Authorization`
/// header (see ApiClient.get's `accessToken`): the interceptor neither
/// replaces that header nor refresh-and-retries the call.
const explicitAuthKey = 'explicitAuth';

bool _isNoRetryPath(String path) =>
    _noRetryPaths.any((prefix) => path.contains(prefix));

/// Attaches the current access token to every request, and on a 401 from
/// anything other than the credential endpoints themselves, attempts
/// exactly one silent refresh-and-retry before giving up. Excluding
/// `/auth/refresh` (and the other [_noRetryPaths]) from the retry path is
/// what prevents an infinite loop if the refresh call itself ever returns
/// 401 (an expired/reused refresh token) — see ARCHITECTURE.md §31.11.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._bridge);

  final Dio _dio;
  final AuthSessionBridge _bridge;

  AuthSessionCallbacks get _callbacks => _bridge.callbacks;

  /// Guards against overlapping refresh attempts when several requests hit
  /// 401 at roughly the same time — they all await the same in-flight
  /// refresh instead of each starting their own. This matters beyond
  /// efficiency: the backend rotates refresh tokens and treats a second use
  /// of an already-rotated token as replay, revoking the whole session
  /// family — so two parallel refreshes would log the user out.
  Future<String?>? _inFlightRefresh;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[explicitAuthKey] == true) {
      handler.next(options);
      return;
    }
    final token = _callbacks.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isAuthEndpoint = _isNoRetryPath(options.path);
    final alreadyRetried = options.extra[_retriedKey] == true;
    final explicitAuth = options.extra[explicitAuthKey] == true;

    if (err.response?.statusCode != 401 ||
        isAuthEndpoint ||
        alreadyRetried ||
        explicitAuth) {
      handler.next(err);
      return;
    }

    // A request that was sent with an access token the app has since
    // replaced (a refresh another request triggered finished while this one
    // was in flight) only needs retrying with the current token — refreshing
    // again would needlessly rotate the session.
    final currentToken = _callbacks.getAccessToken();
    final sentHeader = options.headers['Authorization'];
    if (currentToken != null && sentHeader != 'Bearer $currentToken') {
      await _retry(options, currentToken, handler);
      return;
    }

    final String? newAccessToken;
    try {
      _inFlightRefresh ??= _callbacks.refreshAccessToken().whenComplete(() {
        _inFlightRefresh = null;
      });
      newAccessToken = await _inFlightRefresh;
    } catch (_) {
      // The refresh couldn't be completed (offline, server error, rate
      // limited) — the session itself may still be fine, so surface the
      // original 401 to the caller without ending the session.
      handler.next(err);
      return;
    }

    if (newAccessToken == null) {
      _callbacks.onSessionExpired();
      handler.next(err);
      return;
    }

    await _retry(options, newAccessToken, handler);
  }

  Future<void> _retry(
    RequestOptions options,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final retriedOptions = options
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra[_retriedKey] = true;
      final response = await _dio.fetch<dynamic>(retriedOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
