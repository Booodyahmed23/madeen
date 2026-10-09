import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:mobile/core/network/language_interceptor.dart';

/// Records the headers of each request instead of sending it.
class _RecordingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options.headers);
    return ResponseBody.fromString(
      jsonEncode({}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends the current language on every request', () async {
    var language = 'ar';
    final adapter = _RecordingAdapter();
    final dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(LanguageInterceptor(() => language));

    await dio.get<dynamic>('/notifications');
    language = 'en';
    await dio.get<dynamic>('/notifications');

    expect(adapter.sent[0]['Accept-Language'], 'ar');
    expect(adapter.sent[1]['Accept-Language'], 'en');
  });

  test('apiLanguageCode uses the app language, only ar or en', () {
    expect(apiLanguageCode(const Locale('ar')), 'ar');
    expect(apiLanguageCode(const Locale('ar', 'SA')), 'ar');
    expect(apiLanguageCode(const Locale('en')), 'en');
    expect(apiLanguageCode(const Locale('fr')), 'en');
  });
}
