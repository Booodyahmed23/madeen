import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';

/// The current effective UI language code (`'en'` or `'ar'`) for Course
/// content — same role as `aiAnalysisLanguageProvider`/
/// `tutorLanguageProvider`: `CourseMockDataSource` picks between
/// hand-written English/Arabic copy in the *data* layer, where there is
/// no `BuildContext` to read `AppLocalizations` from.
final courseLanguageProvider = Provider<String>((ref) {
  final locale = ref.watch(localeProvider);
  if (locale != null) return locale.languageCode;
  return PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en';
});
