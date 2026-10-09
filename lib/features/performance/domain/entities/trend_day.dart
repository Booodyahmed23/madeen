/// One day of the accuracy trend (`GET /results/performance/trend`): the
/// revealed answers given that day (device-local day) and how many were
/// correct. [accuracyPercent] is `null` on a day with no answers.
class TrendDay {
  const TrendDay({
    required this.date,
    required this.correct,
    required this.total,
    this.accuracyPercent,
  });

  final DateTime date;
  final int correct;
  final int total;
  final double? accuracyPercent;
}
