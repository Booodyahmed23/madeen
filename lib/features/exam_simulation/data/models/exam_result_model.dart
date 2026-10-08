import '../../domain/entities/exam_result.dart';

class ExamResultModel {
  const ExamResultModel({
    required this.attemptId,
    required this.totalQuestions,
    required this.answered,
    required this.unanswered,
    required this.correct,
    required this.incorrect,
    required this.scorePercent,
    required this.durationTakenSeconds,
    required this.completionStatus,
  });

  factory ExamResultModel.fromJson(Map<String, dynamic> json) {
    return ExamResultModel(
      attemptId: json['attemptId'] as String,
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      answered: (json['answered'] as num).toInt(),
      unanswered: (json['unanswered'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      incorrect: (json['incorrect'] as num).toInt(),
      scorePercent: (json['scorePercent'] as num).toDouble(),
      durationTakenSeconds: (json['durationTakenSeconds'] as num).toInt(),
      completionStatus: json['completionStatus'] as String,
    );
  }

  final String attemptId;
  final int totalQuestions;
  final int answered;
  final int unanswered;
  final int correct;
  final int incorrect;
  final double scorePercent;
  final int durationTakenSeconds;
  final String completionStatus;

  ExamResult toEntity() => ExamResult(
    attemptId: attemptId,
    totalQuestions: totalQuestions,
    answered: answered,
    unanswered: unanswered,
    correct: correct,
    incorrect: incorrect,
    scorePercent: scorePercent,
    durationTaken: Duration(seconds: durationTakenSeconds),
    completionStatus: completionStatus,
  );
}
