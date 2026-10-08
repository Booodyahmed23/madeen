class SubUnit {
  const SubUnit({
    required this.id,
    required this.unitId,
    required this.name,
    this.description,
    this.order = 0,
  });

  final String id;
  final String unitId;
  final String name;
  final String? description;
  final int order;
}
