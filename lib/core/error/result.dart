import 'app_failure.dart';

/// A minimal, dependency-free Result type (Dart 3 sealed classes) so
/// repositories/services can return success-or-failure without throwing
/// across layers. Deliberately hand-written rather than pulling in a
/// functional-programming package — this is the only shape the app needs.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AppFailure failure) = Failure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.value);
    if (self is Failure<T>) return failure(self.failure);
    throw StateError('Unreachable');
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}
