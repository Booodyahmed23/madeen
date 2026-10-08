import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mocktail/mocktail.dart';

import '../auth_screen_harness.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
  });

  Future<void> fill(
    WidgetTester tester, {
    String first = 'Jane',
    String last = 'Doe',
    String email = 'jane@example.com',
    String password = 'Password123',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), first);
    await tester.enterText(fields.at(1), last);
    await tester.enterText(fields.at(2), email);
    await tester.enterText(fields.at(3), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('enforces the backend password policy client-side', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.register,
    );

    await fill(tester, password: 'short1');
    await submit(tester);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);

    await fill(tester, password: 'x' * 201);
    await submit(tester);
    expect(
      find.text('Password must be 200 characters or fewer'),
      findsOneWidget,
    );
    verifyNever(
      () => repository.register(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('a 409 shows "account already exists", localized', (
    tester,
  ) async {
    when(
      () => repository.register(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const Result.failure(
        ConflictFailure('An account with this email already exists'),
      ),
    );
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.register,
    );

    await fill(tester);
    await submit(tester);

    expect(
      find.text(
        'An account with this email already exists. Try logging in instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('trims names and email before sending', (tester) async {
    when(
      () => repository.register(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Result.success(testSession));
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.register,
    );

    await fill(tester, first: ' Jane ', email: ' jane@example.com ');
    await submit(tester);

    verify(
      () => repository.register(
        firstName: 'Jane',
        lastName: 'Doe',
        email: 'jane@example.com',
        password: 'Password123',
      ),
    ).called(1);
  });

  testWidgets(
    '"Log in" goes back to the Login screen it was opened from instead of '
    'stacking a second one',
    (tester) async {
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.login,
      );
      await tester.tap(find.text('Create one'));
      await tester.pumpAndSettle();

      final logIn = find.widgetWithText(TextButton, 'Log in');
      await tester.ensureVisible(logIn);
      await tester.pumpAndSettle();
      await tester.tap(logIn);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing, reason: 'back at the root');
    },
  );

  testWidgets('Arabic renders right-to-left with Arabic validation copy', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.register,
      locale: const Locale('ar'),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(Form))),
      TextDirection.rtl,
    );
    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
  });
}
