import 'package:dio/dio.dart';

/// Sends `Accept-Language` (`en` or `ar`) on every request, so text the API
/// writes for the student — notification titles and bodies (contract §A9)
/// — comes back in the app's language. Other endpoints ignore it.
class LanguageInterceptor extends Interceptor {
  LanguageInterceptor(this._languageCode);

  /// Read on every request, so switching language applies immediately.
  final String Function() _languageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = _languageCode();
    handler.next(options);
  }
}
