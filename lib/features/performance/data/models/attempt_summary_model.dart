import '../../domain/entities/attempt_summary.dart';
import '../../domain/entities/attempt_type.dart';

class AttemptSummaryModel {
  const AttemptSummaryModel({
    required this.attemptId,
    required this.type,
    required this.completedAt,
    required this.contentLabel,
    required this.totalQuestions,
    required this.answered,
    required this.correct,
    required this.scorePercent,
    required this.durationSeconds,
  });

  factory AttemptSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttemptSummaryModel(
      attemptId: json['attemptId'] as String,
      type: AttemptType.fromWire(json['type'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      contentLabel: json['contentLabel'] as String,
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      answered: (json['answered'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      scorePercent: (json['scorePercent'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
    );
  }

  final String attemptId;
  final AttemptType type;
  final DateTime completedAt;
  final String contentLabel;
  final int totalQuestions;
  final int answered;
  final int correct;
  final double scorePercent;
  final int durationSeconds;

  AttemptSummary toEntity() => AttemptSummary(
    attemptId: attemptId,
    type: type,
    completedAt: completedAt,
    contentLabel: contentLabel,
    totalQuestions: totalQuestions,
    answered: answered,
    correct: correct,
    scorePercent: scorePercent,
    duration: Duration(seconds: durationSeconds),
  );
}
