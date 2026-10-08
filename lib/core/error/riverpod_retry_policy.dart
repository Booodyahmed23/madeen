import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_failure.dart';

/// Riverpod 3's `ProviderContainer.defaultRetry` silently retries any
/// provider that throws, up to 10 times with exponential backoff (~200ms up
/// to 6.4s per attempt — over a minute, cumulatively, before giving up).
/// That fights this app's error-handling design: every `AppFailure` is
/// already a deliberately classified, terminal outcome (see
/// core/error/failure_mapper.dart) — a 401/403/404/validation error will
/// never succeed by blindly retrying, and silently retrying a genuine
/// network failure behind a perpetual spinner is worse UX than showing the
/// error immediately with the explicit "Try again" control every screen
/// already has (see shared/widgets/async_list_view.dart).
///
/// Applied once, at the composition root (`ProviderScope(retry: ...)` in
/// main.dart) — tests that build their own `ProviderScope` should use this
/// too, for parity with production behavior.
Duration? appRetryPolicy(int retryCount, Object error) {
  if (error is AppFailure) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}
