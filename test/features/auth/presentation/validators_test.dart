import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/validators.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

/// Validators need a BuildContext (for localized messages), so each case
/// pumps a minimal widget tree rather than calling the static methods bare.
Future<void> _withContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  group('login validation (email + required password)', () {
    testWidgets('rejects an empty email', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.email(context, ''), isNotNull);
      });
    });

    testWidgets('rejects a malformed email', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.email(context, 'not-an-email'), isNotNull);
      });
    });

    testWidgets('accepts a well-formed email', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.email(context, 'jane@example.com'), isNull);
      });
    });

    testWidgets('rejects an empty password', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.required(context, ''), isNotNull);
      });
    });
  });

  group('registration validation (password strength)', () {
    testWidgets('rejects a password shorter than 8 characters', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.password(context, 'Ab1'), isNotNull);
      });
    });

    testWidgets('rejects a password missing a digit', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.password(context, 'onlyletters'), isNotNull);
      });
    });

    testWidgets('rejects a password missing a letter', (tester) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.password(context, '12345678'), isNotNull);
      });
    });

    testWidgets('accepts a password with a letter and a digit, 8+ chars', (
      tester,
    ) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.password(context, 'Password123'), isNull);
      });
    });

    testWidgets('required() rejects empty/whitespace-only names', (
      tester,
    ) async {
      await _withContext(tester, (context) {
        expect(AuthValidators.required(context, ''), isNotNull);
        expect(AuthValidators.required(context, '   '), isNotNull);
        expect(AuthValidators.required(context, 'Jane'), isNull);
      });
    });
  });

  group('limits mirrored from the backend DTOs', () {
    testWidgets('rejects a password longer than 72 characters', (tester) async {
      await _withContext(tester, (context) {
        expect(
          AuthValidators.password(context, 'a1${'x' * 71}'),
          'Password must be 72 characters or fewer',
        );
        expect(AuthValidators.password(context, 'a1${'x' * 70}'), isNull);
      });
    });

    testWidgets('rejects a name longer than 100 characters', (tester) async {
      await _withContext(tester, (context) {
        expect(
          AuthValidators.name(context, 'x' * 101),
          'Must be 100 characters or fewer',
        );
        expect(AuthValidators.name(context, 'x' * 100), isNull);
        expect(AuthValidators.name(context, '   '), 'This field is required');
      });
    });
  });
}
