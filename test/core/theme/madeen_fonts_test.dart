import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/madeen_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled fonts\' OFL texts load and are registered', () async {
    registerMadeenFontLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    final fontEntries = entries.where(
      (e) =>
          e.packages.contains('Newsreader') ||
          e.packages.contains('HankenGrotesk'),
    );

    expect(fontEntries, hasLength(2));
    for (final entry in fontEntries) {
      final text = entry.paragraphs.map((p) => p.text).join(' ');
      expect(text, contains('SIL Open Font License'));
    }
  });
}
