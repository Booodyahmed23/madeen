class Topic {
  const Topic({
    required this.id,
    required this.subUnitId,
    required this.name,
    this.description,
    this.order = 0,
    this.publishedQuestionCount,
  });

  final String id;
  final String subUnitId;
  final String name;
  final String? description;
  final int order;

  /// How many published questions the topic has (`questionCounts.PUBLISHED`
  /// on the tree endpoint), or `null` when unknown.
  final int? publishedQuestionCount;

  /// `false` only when the topic is known to have no questions — there is
  /// nothing to study or be examined on, so the UI disables it.
  bool get hasQuestions => publishedQuestionCount != 0;
}
