import '../../domain/entities/performance_overview.dart';

class PerformanceOverviewModel {
  const PerformanceOverviewModel({
    required this.totalAttempts,
    required this.questionsPracticed,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.overallScorePercent,
    required this.totalTimeSeconds,
    required this.averageTimePerQuestionSeconds,
  });

  factory PerformanceOverviewModel.fromJson(Map<String, dynamic> json) {
    return PerformanceOverviewModel(
      totalAttempts: (json['totalAttempts'] as num).toInt(),
      questionsPracticed: (json['questionsPracticed'] as num).toInt(),
      totalAnswered: (json['totalAnswered'] as num).toInt(),
      totalCorrect: (json['totalCorrect'] as num).toInt(),
      overallScorePercent: (json['overallScorePercent'] as num).toDouble(),
      totalTimeSeconds: (json['totalTimeSeconds'] as num).toInt(),
      averageTimePerQuestionSeconds:
          (json['averageTimePerQuestionSeconds'] as num).toInt(),
    );
  }

  final int totalAttempts;
  final int questionsPracticed;
  final int totalAnswered;
  final int totalCorrect;
  final double overallScorePercent;
  final int totalTimeSeconds;
  final int averageTimePerQuestionSeconds;

  PerformanceOverview toEntity() => PerformanceOverview(
    totalAttempts: totalAttempts,
    questionsPracticed: questionsPracticed,
    totalAnswered: totalAnswered,
    totalCorrect: totalCorrect,
    overallScorePercent: overallScorePercent,
    totalTime: Duration(seconds: totalTimeSeconds),
    averageTimePerQuestion: Duration(seconds: averageTimePerQuestionSeconds),
  );
}
