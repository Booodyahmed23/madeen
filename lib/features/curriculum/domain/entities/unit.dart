class Unit {
  const Unit({
    required this.id,
    required this.partId,
    required this.name,
    this.description,
    this.order = 0,
  });

  final String id;
  final String partId;
  final String name;
  final String? description;
  final int order;
}
