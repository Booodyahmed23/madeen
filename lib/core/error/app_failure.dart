/// Typed failures for the app's error-handling foundation. Feature code
/// should map lower-level exceptions (Dio errors, storage errors, etc.) onto
/// one of these rather than letting raw exceptions reach the UI layer.
///
/// [code] and [details] carry the API's machine-readable error code (e.g.
/// `WRONG_CURRENT_PASSWORD`) when there is one — screens translate known
/// codes via core/error/failure_messages.dart.
sealed class AppFailure {
  const AppFailure(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network error. Please try again.']);
}

class ServerFailure extends AppFailure {
  const ServerFailure(
    super.message, {
    this.statusCode,
    super.code,
    super.details,
  });

  final int? statusCode;
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = 'Please sign in again.']);
}

/// Authenticated, but not allowed (HTTP 403) — distinct from
/// [UnauthorizedFailure] (401, "who are you") because the correct UI
/// response differs: re-authenticating won't fix a 403.
class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = "You don't have permission to do that.",
    String? code,
  ]) : super(code: code);
}

/// A 403 because the student has no active subscription covering what they
/// tried to start (a study session or exam) — the UI responds by offering
/// the Plans screen rather than a dead-end error (contract §G8).
class NoAccessFailure extends ForbiddenFailure {
  const NoAccessFailure([
    super.message = 'An active subscription is required.',
  ]);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {super.code, super.details});
}

/// A resource already exists (e.g. registering with an email already in
/// use) — distinct from [ValidationFailure] because it maps to HTTP 409,
/// not 400, and the UI may want to react differently (e.g. offer a link to
/// log in instead).
class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message, {super.code});
}

/// The requested resource doesn't exist, or isn't visible to this user
/// (HTTP 404 — e.g. an unpublished curriculum node, or another user's
/// session).
class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Not found.', String? code])
    : super(code: code);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
