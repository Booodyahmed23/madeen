/// Typed failures for the app's error-handling foundation. Feature code
/// should map lower-level exceptions (Dio errors, storage errors, etc.) onto
/// one of these rather than letting raw exceptions reach the UI layer.
sealed class AppFailure {
  const AppFailure(this.message);

  final String message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network error. Please try again.']);
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {this.statusCode, this.requestId});

  final int? statusCode;
  final String? requestId;
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
  ]);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// A resource already exists (e.g. registering with an email already in
/// use) — distinct from [ValidationFailure] because it maps to HTTP 409,
/// not 400, and the UI may want to react differently (e.g. offer a link to
/// log in instead).
class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
