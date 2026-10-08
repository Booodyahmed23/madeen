/// Normalized shape of a backend error response — mirrors the envelope
/// produced by the NestJS AllExceptionsFilter (see backend
/// src/common/filters/all-exceptions.filter.ts / ARCHITECTURE.md §21).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.requestId,
  });

  final int statusCode;
  final String message;
  final String? requestId;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
