import '../../l10n/generated/app_localizations.dart';
import 'app_failure.dart';

/// The localized, user-facing sentence for [failure] — what screens should
/// show instead of [AppFailure.message], which carries English defaults or
/// the backend's raw (English) error text and is meant for logs, not users.
/// Screens that know more about their context (e.g. Login knowing a 401
/// means "wrong password", not "session expired") map those cases first
/// and fall back to this.
String localizedFailureMessage(AppLocalizations l10n, AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    UnauthorizedFailure() => l10n.errorSessionExpired,
    ForbiddenFailure() => l10n.errorForbidden,
    ValidationFailure() => l10n.errorValidation,
    ConflictFailure() => l10n.errorConflict,
    ServerFailure(statusCode: 429) => l10n.errorTooManyRequests,
    ServerFailure(:final statusCode) when (statusCode ?? 500) >= 500 =>
      l10n.errorServer,
    ServerFailure() || UnknownFailure() => l10n.errorUnknown,
  };
}
