import '../network/api_exception.dart';
import 'app_failure.dart';

/// Shared mapping from the network layer's [ApiException] onto the domain
/// layer's [AppFailure] hierarchy. Every feature's repository implementation
/// uses this instead of inventing its own status-code branching.
AppFailure mapApiExceptionToFailure(ApiException exception) {
  if (exception.statusCode == 0) {
    return const NetworkFailure();
  }
  if (exception.statusCode == 401) {
    return UnauthorizedFailure(exception.message);
  }
  if (exception.statusCode == 403) {
    return ForbiddenFailure(exception.message);
  }
  if (exception.statusCode == 400 || exception.statusCode == 422) {
    return ValidationFailure(exception.message);
  }
  if (exception.statusCode == 409) {
    return ConflictFailure(exception.message);
  }
  if (exception.statusCode >= 500) {
    return ServerFailure(
      exception.message,
      statusCode: exception.statusCode,
      requestId: exception.requestId,
    );
  }
  return ServerFailure(
    exception.message,
    statusCode: exception.statusCode,
    requestId: exception.requestId,
  );
}
