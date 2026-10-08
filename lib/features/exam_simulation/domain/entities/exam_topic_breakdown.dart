import 'exam_review_item.dart';

/// One topic's share of a submitted simulation — derived by grouping the
/// authoritative post-submission [ExamReviewItem]s, never from anything
/// shown during the exam. Counting only: every correctness verdict comes
/// from the review items themselves.
class ExamTopicBreakdown {
  const ExamTopicBreakdown({
    required this.topicId,
    required this.topicName,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  final String topicId;
  final String topicName;
  final int total;
  final int correct;
  final int wrong;
  final int unanswered;

  int get answered => correct + wrong;

  /// Correct out of every question in this topic (unanswered count against
  /// it, exactly like the overall score).
  double get scorePercent => total == 0 ? 0 : correct / total * 100;
}

/// Groups [review] by topic, in first-seen order. Questions without a
/// topic are left out — there is no honest topic to put them under.
List<ExamTopicBreakdown> examTopicBreakdown(List<ExamReviewItem> review) {
  final groups = <String, List<ExamReviewItem>>{};
  final names = <String, String>{};
  for (final item in review) {
    final topicId = item.topicId;
    if (topicId == null) continue;
    (groups[topicId] ??= []).add(item);
    names[topicId] ??= item.topicName ?? topicId;
  }
  return [
    for (final entry in groups.entries)
      ExamTopicBreakdown(
        topicId: entry.key,
        topicName: names[entry.key]!,
        total: entry.value.length,
        correct: entry.value.where((i) => i.isCorrect).length,
        wrong: entry.value.where((i) => i.isWrong).length,
        unanswered: entry.value.where((i) => i.isUnanswered).length,
      ),
  ];
}
