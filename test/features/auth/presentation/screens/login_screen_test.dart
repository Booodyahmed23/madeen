import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mocktail/mocktail.dart';

import '../auth_screen_harness.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
  });

  void stubLogin(Future<Result<AuthSession>> Function() answer) {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'jane@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
  }

  testWidgets('empty submit shows validation errors and never calls the API', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('This field is required'), findsNWidgets(2));
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets(
    'a 401 shows "Incorrect email or password", not "session expired" or the '
    'raw backend text',
    (tester) async {
      stubLogin(
        () async => const Result.failure(
          UnauthorizedFailure('Invalid email or password'),
        ),
      );
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.login,
      );

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.text('Invalid email or password'), findsNothing);
    },
  );

  testWidgets('offline shows the localized network message', (tester) async {
    stubLogin(() async => const Result.failure(NetworkFailure()));
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );

    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('rate limiting shows the localized "too many attempts" message', (
    tester,
  ) async {
    stubLogin(
      () async => const Result.failure(
        ServerFailure(
          'Too many requests — please try again later.',
          statusCode: 429,
        ),
      ),
    );
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );

    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Too many attempts. Please wait a minute and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('while submitting, the button is disabled and shows progress', (
    tester,
  ) async {
    final pending = Completer<Result<AuthSession>>();
    stubLogin(() => pending.future);
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );

    await fillAndSubmit(tester);
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const Result.success(testSession));
    await tester.pumpAndSettle();
  });

  testWidgets('the error banner clears as soon as the user edits a field', (
    tester,
  ) async {
    stubLogin(() async => const Result.failure(UnauthorizedFailure('nope')));
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );
    await fillAndSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'Password1234');
    await tester.pump();

    expect(find.text('Incorrect email or password.'), findsNothing);
  });

  testWidgets('the password visibility toggle reveals and hides the password', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );
    EditableText passwordText() => tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordText().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(passwordText().obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(passwordText().obscureText, isTrue);
  });

  testWidgets('"Forgot password?" and "Create one" navigate', (tester) async {
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create one'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets(
    'Arabic: RTL layout, localized error, and "Forgot password?" on the '
    'reading-end (left) side',
    (tester) async {
      stubLogin(() async => const Result.failure(UnauthorizedFailure('x')));
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.login,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(Form))),
        TextDirection.rtl,
      );
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final forgot = tester.getCenter(find.text('نسيت كلمة المرور؟'));
      expect(forgot.dx, lessThan(screenWidth / 2));

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'jane@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('dark mode renders on the dark color scheme', (tester) async {
    await pumpAuthScreen(
      tester,
      repository: repository,
      initialLocation: AppRoutes.login,
      themeMode: ThemeMode.dark,
    );

    final context = tester.element(find.byType(Form));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
