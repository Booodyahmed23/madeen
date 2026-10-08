import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';

/// The current effective UI language code (`'en'` or `'ar'`) for AI Analysis
/// content generation. Every other feature's static UI strings resolve
/// their language via `AppLocalizations.of(context)`, but AI Analysis
/// content is produced in the *data* layer (AiAnalysisMockDataSource picks
/// between hand-written English/Arabic copy there; a real backend would use
/// this as a `locale` query parameter — see AI_ANALYSIS_API_REQUIREMENTS.md)
/// where there is no `BuildContext` — hence this feature-local provider
/// rather than reusing `AppLocalizations` directly.
///
/// [localeProvider] being `null` means "follow system locale" (see that
/// provider's doc comment); this resolves that the same way
/// `MaterialApp`'s own locale resolution would for this app's exactly two
/// supported locales (`AppLocalizations.supportedLocales` — English,
/// Arabic).
final aiAnalysisLanguageProvider = Provider<String>((ref) {
  final locale = ref.watch(localeProvider);
  if (locale != null) return locale.languageCode;
  return PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en';
});
