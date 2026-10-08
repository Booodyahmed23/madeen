/// A certification program (e.g. CMA, FMAA). Top of the curriculum
/// hierarchy — see ARCHITECTURE.md's Program → Part → Unit → Sub-unit →
/// Topic structure. `name` and `description` are single-language, shown as
/// authored (contract §G7).
class Program {
  const Program({
    required this.id,
    required this.name,
    this.description,
    this.order = 0,
    this.isPublished = true,
  });

  final String id;
  final String name;
  final String? description;
  final int order;

  /// Students only ever receive published nodes, so this is `true` in
  /// practice.
  final bool isPublished;
}
