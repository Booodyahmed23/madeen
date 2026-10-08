import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the SIL Open Font License texts of the bundled MADEEN fonts
/// (Newsreader, Hanken Grotesk — see pubspec.yaml) with Flutter's license
/// registry, so they appear in the standard licenses page alongside every
/// package license. Loaded lazily, only when that page is opened.
void registerMadeenFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final family in const ['Newsreader', 'HankenGrotesk']) {
      final text = await rootBundle.loadString('assets/fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
