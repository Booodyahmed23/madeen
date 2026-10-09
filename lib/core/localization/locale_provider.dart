import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefKey = 'app_locale';

/// English + Arabic per ARCHITECTURE.md §19. `null` means "follow system
/// locale" (falls back to English if the system locale isn't supported —
/// see supportedLocales in main.dart).
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_localePrefKey);
    if (stored != null) {
      state = Locale(stored);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localePrefKey);
    } else {
      await prefs.setString(_localePrefKey, locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

/// The language code the API should write in: the app's chosen language,
/// else the device's — `ar` for Arabic, `en` for anything else.
String apiLanguageCode(Locale? appLocale) {
  // PlatformDispatcher, not WidgetsBinding: works before the binding exists
  // (and in plain unit tests).
  final code =
      appLocale?.languageCode ??
      PlatformDispatcher.instance.locale.languageCode;
  return code == 'ar' ? 'ar' : 'en';
}
