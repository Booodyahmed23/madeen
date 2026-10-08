/// Active access to one program — `GET /entitlements/me` (contract §A6).
/// The API returns active entitlements only, soonest expiry first.
class Entitlement {
  const Entitlement({
    required this.id,
    required this.programId,
    required this.programName,
    required this.startsAt,
    required this.expiresAt,
  });

  final String id;
  final String programId;
  final String programName;
  final DateTime startsAt;
  final DateTime expiresAt;
}
