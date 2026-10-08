/// Normalized shape of a backend error response — mirrors the API's error
/// envelope `{ statusCode, error, message, code?, details?, path, timestamp }`
/// (see docs/MOBILE_API_CONTRACT.md §G2).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
  });

  final int statusCode;

  /// The backend's message, with a `string[]` (validation) message joined
  /// by `, `. English and meant for logs — screens show a localized
  /// sentence instead (see core/error/failure_messages.dart).
  final String message;

  /// Machine-readable error code (e.g. `WRONG_CURRENT_PASSWORD`), present on
  /// errors the app is expected to tell apart. `null` for most errors.
  final String? code;

  /// Extra structured data some codes carry (e.g. `{ max: 20 }`).
  final Map<String, dynamic>? details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() =>
      'ApiException($statusCode${code == null ? '' : ' $code'}, $message)';
}
