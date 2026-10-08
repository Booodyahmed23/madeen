/// A plan a student can subscribe to — `GET /plans` (contract §A6). Prices
/// are in minor units (cents).
class Plan {
  const Plan({
    required this.id,
    required this.programId,
    required this.programName,
    required this.name,
    this.description,
    required this.priceCents,
    required this.currency,
    required this.durationDays,
  });

  final String id;
  final String programId;
  final String programName;
  final String name;
  final String? description;
  final int priceCents;

  /// ISO 4217 code, e.g. `USD`.
  final String currency;
  final int durationDays;

  bool get isFree => priceCents == 0;
}
