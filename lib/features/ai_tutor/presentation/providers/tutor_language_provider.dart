import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';

/// The current effective UI language code (`'en'` or `'ar'`) for AI Tutor
/// responses — same role, and same reasoning, as AI Analysis's own
/// `aiAnalysisLanguageProvider`: `MockAiProvider` picks between hand-written
/// English/Arabic replies in the *data* layer, where there is no
/// `BuildContext` to read `AppLocalizations` from.
final tutorLanguageProvider = Provider<String>((ref) {
  final locale = ref.watch(localeProvider);
  if (locale != null) return locale.languageCode;
  return PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en';
});
