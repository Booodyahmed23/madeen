import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/app_config.dart';

void main() {
  test('rewrites localhost to the host loopback on Android', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        'http://localhost:3001/api/v1',
        platform: TargetPlatform.android,
      ),
      'http://10.0.2.2:3001/api/v1',
    );
  });

  test('keeps localhost on iOS', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        'http://localhost:3001/api/v1',
        platform: TargetPlatform.iOS,
      ),
      'http://localhost:3001/api/v1',
    );
  });

  test('never rewrites a real host', () {
    expect(
      AppConfig.resolveApiBaseUrl(
        'https://kasbana.net/api/v1',
        platform: TargetPlatform.android,
      ),
      'https://kasbana.net/api/v1',
    );
  });
}
