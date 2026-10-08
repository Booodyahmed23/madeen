import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/failure_messages.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('every failure type maps to a localized sentence, never the raw '
      'English/backend message', () {
    const failures = <AppFailure>[
      NetworkFailure(),
      UnauthorizedFailure('Invalid or expired access token'),
      ForbiddenFailure('Insufficient permissions'),
      ValidationFailure('password must contain at least one letter'),
      ConflictFailure('An account with this email already exists'),
      ServerFailure('Too many requests', statusCode: 429),
      ServerFailure('Internal server error', statusCode: 500),
      ServerFailure('Not found', statusCode: 404),
      UnknownFailure(),
    ];
    for (final failure in failures) {
      final english = localizedFailureMessage(en, failure);
      final arabic = localizedFailureMessage(ar, failure);
      expect(english, isNot(failure.message), reason: '$failure');
      expect(arabic, isNot(english), reason: '$failure has no Arabic copy');
    }
  });

  test('maps each failure to its specific message', () {
    expect(
      localizedFailureMessage(en, const NetworkFailure()),
      en.errorNetwork,
    );
    expect(
      localizedFailureMessage(en, const UnauthorizedFailure('x')),
      en.errorSessionExpired,
    );
    expect(
      localizedFailureMessage(en, const ServerFailure('x', statusCode: 429)),
      en.errorTooManyRequests,
    );
    expect(
      localizedFailureMessage(en, const ServerFailure('x', statusCode: 502)),
      en.errorServer,
    );
    expect(
      localizedFailureMessage(en, const ServerFailure('x', statusCode: 404)),
      en.errorUnknown,
    );
  });
}
