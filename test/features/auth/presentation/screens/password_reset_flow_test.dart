import 'dart:async';

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

  group('Forgot Password', () {
    testWidgets(
      'shows the same success message whatever the email (no enumeration)',
      (tester) async {
        when(() => repository.forgotPassword(any()))
            .thenAnswer((_) async => const Result.success(null));
        await pumpAuthScreen(
          tester,
          repository: repository,
          initialLocation: AppRoutes.forgotPassword,
        );

        await tester.enterText(find.byType(TextFormField), 'who@example.com');
        await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'If an account exists for this email, a reset link has been sent.',
          ),
          findsOneWidget,
        );
        verify(() => repository.forgotPassword('who@example.com')).called(1);
      },
    );

    testWidgets('a failure shows a localized error and keeps the form', (
      tester,
    ) async {
      when(() => repository.forgotPassword(any()))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.forgotPassword,
      );

      await tester.enterText(find.byType(TextFormField), 'who@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Can't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets(
      '"Enter code" opens Reset Password — the in-app path to that screen',
      (tester) async {
        await pumpAuthScreen(
          tester,
          repository: repository,
          initialLocation: AppRoutes.forgotPassword,
        );

        await tester.tap(find.text('Enter code'));
        await tester.pumpAndSettle();

        expect(find.text('Set a new password'), findsOneWidget);
      },
    );
  });

  group('Reset Password', () {
    void stubReset(Future<Result<void>> Function() answer) {
      when(
        () => repository.resetPassword(
          token: any(named: 'token'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) => answer());
    }

    Future<void> submit(WidgetTester tester, {String token = 'abc.def'}) async {
      await tester.enterText(find.byType(TextFormField).at(0), token);
      await tester.enterText(find.byType(TextFormField).at(1), 'NewPass123');
      await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    }

    testWidgets('prefills the token from a ?token= link', (tester) async {
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: '${AppRoutes.resetPassword}?token=abc.def',
      );

      expect(find.text('abc.def'), findsOneWidget);
    });

    testWidgets(
      'a rejected token (400) says so and offers to request a new code',
      (tester) async {
        stubReset(
          () async => const Result.failure(
            ValidationFailure('Invalid or expired reset token'),
          ),
        );
        await pumpAuthScreen(
          tester,
          repository: repository,
          initialLocation: AppRoutes.forgotPassword,
        );
        await tester.tap(find.text('Enter code'));
        await tester.pumpAndSettle();

        await submit(tester);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'This reset code is invalid or has expired. Request a new one.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Request a new code'));
        await tester.pumpAndSettle();
        expect(find.text('Send reset link'), findsOneWidget);
      },
    );

    testWidgets('loading, then success with a way back to Log in', (
      tester,
    ) async {
      final pending = Completer<Result<void>>();
      stubReset(() => pending.future);
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.resetPassword,
      );

      await submit(tester);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(
        find.text('Password updated. Please log in again.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('dark mode + Arabic render without layout errors', (
      tester,
    ) async {
      await pumpAuthScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.resetPassword,
        locale: const Locale('ar'),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('تعيين كلمة مرور جديدة'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(Form))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
