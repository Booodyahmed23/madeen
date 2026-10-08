import '../../domain/entities/session_result.dart';

class SessionResultModel {
  const SessionResultModel({
    required this.sessionId,
    required this.totalQuestions,
    required this.answered,
    required this.unanswered,
    required this.correct,
    required this.incorrect,
    required this.scorePercent,
    required this.totalTimeSeconds,
    required this.averageTimePerQuestionSeconds,
  });

  factory SessionResultModel.fromJson(Map<String, dynamic> json) {
    return SessionResultModel(
      sessionId: json['sessionId'] as String,
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      answered: (json['answered'] as num).toInt(),
      unanswered: (json['unanswered'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      incorrect: (json['incorrect'] as num).toInt(),
      scorePercent: (json['scorePercent'] as num).toDouble(),
      totalTimeSeconds: (json['totalTimeSeconds'] as num).toInt(),
      averageTimePerQuestionSeconds:
          (json['averageTimePerQuestionSeconds'] as num).toDouble(),
    );
  }

  final String sessionId;
  final int totalQuestions;
  final int answered;
  final int unanswered;
  final int correct;
  final int incorrect;
  final double scorePercent;
  final int totalTimeSeconds;
  final double averageTimePerQuestionSeconds;

  SessionResult toEntity() => SessionResult(
    sessionId: sessionId,
    totalQuestions: totalQuestions,
    answered: answered,
    unanswered: unanswered,
    correct: correct,
    incorrect: incorrect,
    scorePercent: scorePercent,
    totalTime: Duration(seconds: totalTimeSeconds),
    averageTimePerQuestion: Duration(
      milliseconds: (averageTimePerQuestionSeconds * 1000).round(),
    ),
  );
}
