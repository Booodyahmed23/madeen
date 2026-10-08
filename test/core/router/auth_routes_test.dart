import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/subscription/access_overrides.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  role: 'USER',
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

const _loginTitle = 'Welcome back';
const _homeSubtitle = 'Pass CMA & FMAA with confidence';

/// Pumps the real App (real router + redirect). Every non-auth feature runs
/// on its default sample-data source, so Home renders without mocks.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  MockAuthRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      ...accessOverrides(),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
  });

  group('signed out', () {
    setUp(() {
      when(() => repository.restoreSession()).thenAnswer((_) async => null);
    });

    testWidgets('every protected route redirects to Login', (tester) async {
      final container = await _pumpApp(tester, repository);
      final router = container.read(appRouterProvider);

      for (final path in [
        AppRoutes.profile,
        AppRoutes.courses,
        AppRoutes.performanceOverview,
        AppRoutes.aiTutor,
        AppRoutes.notifications,
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.text(_loginTitle), findsOneWidget, reason: path);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          AppRoutes.login,
          reason: path,
        );
      }
    });

    testWidgets('public routes stay reachable, including a reset link with a '
        'token', (tester) async {
      final container = await _pumpApp(tester, repository);
      final router = container.read(appRouterProvider);

      router.go('${AppRoutes.resetPassword}?token=abc.def');
      await tester.pumpAndSettle();

      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.text('abc.def'), findsOneWidget);
    });
  });

  group('signed in', () {
    setUp(() {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
    });

    testWidgets('public auth routes bounce back to Home', (tester) async {
      final container = await _pumpApp(tester, repository);
      final router = container.read(appRouterProvider);

      for (final path in [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.text(_homeSubtitle), findsOneWidget, reason: path);
      }
    });

    testWidgets('confirmed logout from Home lands on Login', (tester) async {
      when(() => repository.logout()).thenAnswer((_) async {});
      await _pumpApp(tester, repository);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pumpAndSettle();

      expect(find.text(_loginTitle), findsOneWidget);
      verify(() => repository.logout()).called(1);
    });

    testWidgets(
      'a session the server rejects mid-use (refresh fails) drops to Login',
      (tester) async {
        final container = await _pumpApp(tester, repository);
        expect(find.text(_homeSubtitle), findsOneWidget);

        when(() => repository.refreshAccessToken())
            .thenAnswer((_) async => null);
        await container.read(authNotifierProvider.notifier).silentRefresh();
        await tester.pumpAndSettle();

        expect(find.text(_loginTitle), findsOneWidget);
      },
    );
  });

  group('offline at launch', () {
    setUp(() {
      when(() => repository.restoreSession()).thenThrow(const NetworkFailure());
    });

    testWidgets('shows Session Unavailable instead of signing the user out', (
      tester,
    ) async {
      await _pumpApp(tester, repository);

      expect(find.text("Couldn't restore your session"), findsOneWidget);
      expect(find.text(_loginTitle), findsNothing);
      verifyNever(() => repository.logout());
    });

    testWidgets('Try again restores the session once back online', (
      tester,
    ) async {
      await _pumpApp(tester, repository);

      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text(_homeSubtitle), findsOneWidget);
    });

    testWidgets('Log out discards the stored session and shows Login', (
      tester,
    ) async {
      when(() => repository.logout()).thenAnswer((_) async {});
      await _pumpApp(tester, repository);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      verify(() => repository.logout()).called(1);
      expect(find.text(_loginTitle), findsOneWidget);
    });

    testWidgets('renders in Arabic', (tester) async {
      final container = ProviderContainer(
        overrides: [
          ...accessOverrides(),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('ar'));
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذّرت استعادة جلستك'), findsOneWidget);
    });
  });
}
