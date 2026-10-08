import 'package:intl/intl.dart';

/// MADEEN shows Western digits in Arabic too — scores, timers, question
/// numbers and reminder times (MaterialLocalizations) all do. `intl`'s
/// DateFormat would otherwise switch to Arabic-Indic digits for `ar`, so a
/// date ("٢٥ سبتمبر") would sit next to a time or score in the other
/// numeral system. Call once at startup, before any date is formatted.
void useWesternDigitsInDates() {
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
}
