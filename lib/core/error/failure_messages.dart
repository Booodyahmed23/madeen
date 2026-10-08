import '../../l10n/generated/app_localizations.dart';
import 'app_failure.dart';

/// The localized, user-facing sentence for [failure] — what screens should
/// show instead of [AppFailure.message], which carries English defaults or
/// the backend's raw (English) error text and is meant for logs, not users.
/// Screens that know more about their context (e.g. Login knowing a 401
/// means "wrong password", not "session expired") map those cases first
/// and fall back to this.
///
/// A known API error `code` wins over the failure type; an unknown code
/// falls through to the generic message for its type (contract §G2).
String localizedFailureMessage(AppLocalizations l10n, AppFailure failure) {
  final byCode = _messageForCode(l10n, failure.code);
  if (byCode != null) return byCode;
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    UnauthorizedFailure() => l10n.errorSessionExpired,
    NoAccessFailure() => l10n.errorNoAccess,
    ForbiddenFailure() => l10n.errorForbidden,
    ValidationFailure() => l10n.errorValidation,
    ConflictFailure() => l10n.errorConflict,
    NotFoundFailure() => l10n.errorNotFound,
    ServerFailure(statusCode: 429) => l10n.errorTooManyRequests,
    ServerFailure(:final statusCode) when (statusCode ?? 500) >= 500 =>
      l10n.errorServer,
    ServerFailure() || UnknownFailure() => l10n.errorUnknown,
  };
}

String? _messageForCode(AppLocalizations l10n, String? code) {
  return switch (code) {
    'WRONG_CURRENT_PASSWORD' => l10n.errorWrongCurrentPassword,
    'SAME_PASSWORD' => l10n.errorSamePassword,
    'ADMIN_SELF_DELETE' => l10n.errorAdminSelfDelete,
    'NOT_FOUND' => l10n.errorNotFound,
    'COUPON_INVALID' => l10n.errorCouponInvalid,
    'COUPON_NOT_ACTIVE' => l10n.errorCouponNotActive,
    'COUPON_WRONG_PLAN' => l10n.errorCouponWrongPlan,
    'COUPON_EXHAUSTED' => l10n.errorCouponExhausted,
    'COUPON_ALREADY_USED' => l10n.errorCouponAlreadyUsed,
    'COUPON_NOT_FREE' => l10n.errorCouponNotFree,
    'PLAN_UNAVAILABLE' => l10n.errorPlanUnavailable,
    _ => null,
  };
}
