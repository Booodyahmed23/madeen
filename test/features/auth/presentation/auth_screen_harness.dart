import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/profile_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const testUser = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  role: 'USER',
);
const testSession = AuthSession(user: testUser, accessToken: 'access-token-1');

/// Pumps the five auth screens behind a real GoRouter (they navigate with
/// `context.push/go/pop`), starting at [initialLocation]. Only the
/// repository is mocked — the real AuthNotifier runs. No auth redirect is
/// installed here: that's covered against the real router in
/// test/core/router/auth_routes_test.dart.
Future<void> pumpAuthScreen(
  WidgetTester tester, {
  required MockAuthRepository repository,
  required String initialLocation,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, state) => ResetPasswordScreen(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationPreferences,
        builder: (_, _) => const Scaffold(body: Text('NOTIFICATION SETTINGS')),
      ),
      GoRoute(
        path: AppRoutes.studyReminders,
        builder: (_, _) => const Scaffold(body: Text('STUDY REMINDERS')),
      ),
    ],
  );
  addTearDown(router.dispose);

  // Like the real app (app/app.dart only mounts the router once auth has
  // settled), let session restoration finish before any screen mounts.
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  container.read(authNotifierProvider);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
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
      ),
    ),
  );
  // `settle: false` for screens that are mid-load (an indeterminate
  // progress indicator never settles).
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

/// The FilledButton whose label is [label] — for asserting enabled state.
FilledButton filledButton(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
