/// One device where the student is signed in — a row of
/// `GET /auth/sessions` (contract §A1). The [id] changes each time that
/// device refreshes its token, so sign-outs use the id from a fresh list.
class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.userAgent,
    required this.lastActiveAt,
    required this.isCurrent,
    this.ipAddress,
  });

  final String id;
  final String userAgent;
  final String? ipAddress;

  /// Last sign-in or token refresh.
  final DateTime lastActiveAt;

  /// This device.
  final bool isCurrent;
}
