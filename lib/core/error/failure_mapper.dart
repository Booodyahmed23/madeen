import '../network/api_exception.dart';
import 'app_failure.dart';

/// Messages the API sends with a `403` when starting a study session or exam
/// without an entitlement (contract §G8). These carry no `code`, so the
/// message text is the only way to tell them from other 403s.
const _noAccessMessages = {
  'An active subscription is required',
  'No active subscription covers one or more selected topics',
};

/// Shared mapping from the network layer's [ApiException] onto the domain
/// layer's [AppFailure] hierarchy. Every feature's repository implementation
/// uses this instead of inventing its own status-code branching.
AppFailure mapApiExceptionToFailure(ApiException exception) {
  final status = exception.statusCode;
  if (status == 0) {
    return const NetworkFailure();
  }
  if (status == 401) {
    return UnauthorizedFailure(exception.message);
  }
  if (status == 403) {
    if (_noAccessMessages.contains(exception.message)) {
      return NoAccessFailure(exception.message);
    }
    return ForbiddenFailure(exception.message, exception.code);
  }
  if (status == 404) {
    return NotFoundFailure(exception.message, exception.code);
  }
  if (status == 400 || status == 422) {
    return ValidationFailure(
      exception.message,
      code: exception.code,
      details: exception.details,
    );
  }
  if (status == 409) {
    return ConflictFailure(exception.message, code: exception.code);
  }
  return ServerFailure(
    exception.message,
    statusCode: status,
    code: exception.code,
    details: exception.details,
  );
}
