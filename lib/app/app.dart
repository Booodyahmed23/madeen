import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_provider.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/auth/presentation/screens/session_unavailable_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/madeen/madeen.dart';
import 'practice_attempt_recorder.dart';
import 'push_sync.dart';
import 'reminder_sync.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // Restoring a persisted session (or determining there isn't one) must
    // finish before the router's redirect logic runs — otherwise a
    // returning signed-in user would flash the login screen first. See
    // ARCHITECTURE.md §31 / Phase 2: "Initializing", "Unauthenticated", and
    // "Authenticated" are the three states navigation reacts to. A stored
    // session that couldn't be confirmed (offline at launch) gets its own
    // pre-router screen too — see SessionUnavailableScreen.
    final authState = ref.watch(authNotifierProvider);
    // Keeps completed practice attempts flowing into Performance for the
    // app's whole lifetime — see practice_attempt_recorder.dart.
    ref.watch(practiceAttemptRecorderProvider);
    ref.watch(reminderSyncProvider);
    ref.watch(pushSyncProvider);

    if (authState is AuthInitializing || authState is AuthSessionUnavailable) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.madeenLight,
        darkTheme: AppTheme.madeenDark,
        builder: AppTheme.localeAwareBuilder,
        themeMode: themeMode,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: authState is AuthSessionUnavailable
            ? SessionUnavailableScreen(state: authState)
            : const Scaffold(body: MadeenPageLoading()),
      );
    }

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.madeenLight,
      darkTheme: AppTheme.madeenDark,
      builder: AppTheme.localeAwareBuilder,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
