import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mocktail/mocktail.dart';

import '../auth_screen_harness.dart';

const _fresh = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Janet',
  lastName: 'Doe',
  role: 'USER',
);

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.restoreSession())
        .thenAnswer((_) async => testSession);
    when(() => repository.getCurrentUser())
        .thenAnswer((_) async => const Result.success(testUser));
  });

  void stubUpdate(Future<Result<AuthUser>> Function() answer) {
    when(
      () => repository.updateProfile(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpAuthScreen(
    tester,
    repository: repository,
    initialLocation: AppRoutes.profile,
    locale: locale,
    themeMode: themeMode,
  );

  testWidgets(
    'loads the current user from the server on open (showing a progress bar '
    'meanwhile), and shows the fresh values',
    (tester) async {
      final load = Completer<Result<AuthUser>>();
      when(() => repository.getCurrentUser()).thenAnswer((_) => load.future);
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.profile,
        settle: false,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      load.complete(const Result.success(_fresh));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Janet'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed load is non-blocking: cached values stay editable and Retry '
    'recovers',
    (tester) async {
      when(() => repository.getCurrentUser())
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await open(tester);

      expect(
        find.text(
          "Couldn't refresh your profile. Showing your last saved details.",
        ),
        findsOneWidget,
      );
      expect(find.text('Jane'), findsOneWidget);

      when(() => repository.getCurrentUser())
          .thenAnswer((_) async => const Result.success(_fresh));
      await tester.tap(find.widgetWithText(TextButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Couldn't refresh your profile. Showing your last saved details.",
        ),
        findsNothing,
      );
      expect(find.text('Janet'), findsOneWidget);
    },
  );

  testWidgets('Save is disabled until something actually changes', (
    tester,
  ) async {
    await open(tester);
    expect(filledButton(tester, 'Save changes').onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'Janet');
    await tester.pump();
    expect(filledButton(tester, 'Save changes').onPressed, isNotNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'Jane');
    await tester.pump();
    expect(filledButton(tester, 'Save changes').onPressed, isNull);
  });

  testWidgets('save: loading -> success message -> cleared on next edit', (
    tester,
  ) async {
    final pending = Completer<Result<AuthUser>>();
    stubUpdate(() => pending.future);
    await open(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Janet');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const Result.success(_fresh));
    await tester.pumpAndSettle();
    expect(find.text('Profile updated'), findsOneWidget);
    verify(() => repository.updateProfile(firstName: 'Janet', lastName: 'Doe'))
        .called(1);

    await tester.enterText(find.byType(TextFormField).at(1), 'Doe-Smith');
    await tester.pump();
    expect(find.text('Profile updated'), findsNothing);
  });

  testWidgets('save failure shows a localized error, never the raw message', (
    tester,
  ) async {
    stubUpdate(
      () async => const Result.failure(
        ValidationFailure('firstName must be shorter than 100 characters'),
      ),
    );
    await open(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Janet');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Some of the details you entered aren't valid. Please check them and try again.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('firstName must'), findsNothing);
  });

  testWidgets('rejects an empty name client-side', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextFormField).at(1), '  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required'), findsOneWidget);
    verifyNever(
      () => repository.updateProfile(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      ),
    );
  });

  testWidgets('logout asks for confirmation; Cancel keeps the session', (
    tester,
  ) async {
    when(() => repository.logout()).thenAnswer((_) async {});
    await open(tester);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.logout());

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    verify(() => repository.logout()).called(1);
  });

  testWidgets('offers no fake account features the backend lacks', (
    tester,
  ) async {
    await open(tester);

    for (final label in ['Change email', 'Avatar']) {
      expect(find.textContaining(label), findsNothing);
    }
  });

  testWidgets('offers Change password and Delete account', (tester) async {
    await open(tester);

    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('Arabic + dark: RTL, dark scheme, Arabic copy', (tester) async {
    await open(tester, locale: const Locale('ar'), themeMode: ThemeMode.dark);

    final context = tester.element(find.byType(Form));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('ملفك الشخصي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
