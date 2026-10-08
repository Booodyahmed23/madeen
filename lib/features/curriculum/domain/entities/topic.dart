class Topic {
  const Topic({
    required this.id,
    required this.subUnitId,
    required this.name,
    this.description,
    this.order = 0,
  });

  final String id;
  final String subUnitId;
  final String name;
  final String? description;
  final int order;
}
