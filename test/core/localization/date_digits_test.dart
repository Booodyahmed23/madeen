import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/localization/date_digits.dart';

/// Formats [date] the way the app's screens do — inside an Arabic
/// MaterialApp, so flutter_localizations' own `ar` date symbols (which
/// default to Arabic-Indic digits) are the ones in effect.
Future<String> _formatInArabicApp(WidgetTester tester, DateTime date) async {
  late String formatted;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) {
          final locale = Localizations.localeOf(context).toString();
          formatted = DateFormat.MMMd(locale).format(date);
          return const SizedBox();
        },
      ),
    ),
  );
  return formatted;
}

void main() {
  tearDown(() => DateFormat.useNativeDigitsByDefaultFor('ar', true));

  testWidgets('without it, Arabic dates would use Arabic-Indic digits', (
    tester,
  ) async {
    DateFormat.useNativeDigitsByDefaultFor('ar', true);

    final formatted = await _formatInArabicApp(tester, DateTime(2026, 9, 25));

    expect(formatted, contains('٢٥'));
  });

  testWidgets('Arabic dates use Western digits, like the rest of the app', (
    tester,
  ) async {
    useWesternDigitsInDates();

    final formatted = await _formatInArabicApp(tester, DateTime(2026, 9, 25));

    expect(formatted, contains('25'));
    expect(formatted, isNot(matches(RegExp('[٠-٩]'))));
  });
}
