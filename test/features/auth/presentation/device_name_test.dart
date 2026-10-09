import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/widgets/device_name.dart';

void main() {
  test('names the app and common browsers with their OS', () {
    expect(
      deviceNameFromUserAgent('MADEEN (ios; Version 18.2 (Build 22C150))'),
      'MADEEN app · iPhone',
    );
    expect(
      deviceNameFromUserAgent('MADEEN (android; 14)'),
      'MADEEN app · Android',
    );
    expect(
      deviceNameFromUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0 Safari/537.36',
      ),
      'Chrome · Windows',
    );
    expect(
      deviceNameFromUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.5 Safari/605.1.15',
      ),
      'Safari · Mac',
    );
    expect(
      deviceNameFromUserAgent(
        'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/131 '
        'Safari/537.36 Edg/131.0',
      ),
      'Edge · Windows',
    );
  });

  test('an unknown agent is shown shortened, never empty', () {
    expect(deviceNameFromUserAgent('curl/8.7.1'), 'curl/8.7.1');
    expect(deviceNameFromUserAgent(''), '—');
    expect(deviceNameFromUserAgent('x' * 60).length, 41);
  });
}
