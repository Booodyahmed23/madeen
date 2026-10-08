/// A certification program (e.g. CMA, FMAA). Top of the curriculum
/// hierarchy — see ARCHITECTURE.md's Program → Part → Unit → Sub-unit →
/// Topic structure.
class Program {
  const Program({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.imageUrl,
    this.order = 0,
    this.isActive,
  });

  final String id;
  final String name;
  final String code;
  final String? description;
  final String? imageUrl;
  final int order;

  /// `null` when the API doesn't expose a published/active flag at all —
  /// treated as "assume visible" by the UI, not as false.
  final bool? isActive;
}
