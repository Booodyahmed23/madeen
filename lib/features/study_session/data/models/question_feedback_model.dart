import '../../domain/entities/question_feedback.dart';

class QuestionFeedbackModel {
  const QuestionFeedbackModel({
    required this.questionId,
    required this.isCorrect,
    required this.correctChoiceId,
    this.explanation,
  });

  factory QuestionFeedbackModel.fromJson(Map<String, dynamic> json) {
    return QuestionFeedbackModel(
      questionId: json['questionId'] as String,
      isCorrect: json['isCorrect'] as bool,
      correctChoiceId: json['correctChoiceId'] as String,
      explanation: json['explanation'] as String?,
    );
  }

  final String questionId;
  final bool isCorrect;
  final String correctChoiceId;
  final String? explanation;

  QuestionFeedback toEntity() => QuestionFeedback(
    questionId: questionId,
    isCorrect: isCorrect,
    correctChoiceId: correctChoiceId,
    explanation: explanation,
  );
}
