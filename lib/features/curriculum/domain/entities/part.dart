class Part {
  const Part({
    required this.id,
    required this.programId,
    required this.name,
    this.description,
    this.order = 0,
  });

  final String id;
  final String programId;
  final String name;
  final String? description;
  final int order;
}
