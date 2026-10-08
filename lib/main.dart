import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/error/riverpod_retry_policy.dart';
import 'core/localization/date_digits.dart';
import 'core/theme/madeen_fonts.dart';

void main() {
  registerMadeenFontLicenses();
  useWesternDigitsInDates();
  runApp(ProviderScope(retry: appRetryPolicy, child: const App()));
}
