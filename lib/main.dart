import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/local_user_data_wipers.dart';
import 'app/sign_out_hooks.dart';
import 'core/error/riverpod_retry_policy.dart';
import 'core/localization/date_digits.dart';
import 'core/session/sign_out_hooks.dart';
import 'core/storage/local_user_data.dart';
import 'core/theme/madeen_fonts.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  registerMadeenFontLicenses();
  useWesternDigitsInDates();
  runApp(
    ProviderScope(
      retry: appRetryPolicy,
      overrides: [
        localUserDataWipersProvider.overrideWith(appLocalUserDataWipers),
        signOutHooksProvider.overrideWith(appSignOutHooks),
      ],
      child: const App(),
    ),
  );
}

/// Firebase is only used for push notifications. On platforms without
/// options (web, desktop), or if it fails to start, the app runs without push.
Future<void> _initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options == null) return;
  try {
    await Firebase.initializeApp(options: options);
  } catch (error) {
    debugPrint('Firebase not started, push notifications off: $error');
  }
}
