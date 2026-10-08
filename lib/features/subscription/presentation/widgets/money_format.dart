import 'package:intl/intl.dart';

/// A minor-unit amount as currency, e.g. `2900, 'USD'` → `$29.00`. Western
/// digits in every locale, like the rest of the app's numbers.
String formatMoney(int cents, String currency) {
  return NumberFormat.simpleCurrency(
    locale: 'en',
    name: currency,
  ).format(cents / 100);
}
