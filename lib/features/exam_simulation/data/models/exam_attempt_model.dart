import '../../domain/entities/exam_attempt.dart';
import 'exam_question_model.dart';

class ExamAttemptModel {
  const ExamAttemptModel({
    required this.attemptId,
    required this.questions,
    required this.durationSeconds,
  });

  factory ExamAttemptModel.fromJson(Map<String, dynamic> json) {
    return ExamAttemptModel(
      attemptId: json['attemptId'] as String,
      questions: (json['questions'] as List)
          .map((q) => ExamQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
    );
  }

  final String attemptId;
  final List<ExamQuestionModel> questions;
  final int durationSeconds;

  ExamAttempt toEntity() => ExamAttempt(
    attemptId: attemptId,
    questions: questions.map((q) => q.toEntity()).toList(),
    durationSeconds: durationSeconds,
  );
}
