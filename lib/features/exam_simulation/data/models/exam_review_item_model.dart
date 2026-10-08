import '../../domain/entities/exam_review_item.dart';
import 'exam_answer_choice_model.dart';

class ExamReviewItemModel {
  const ExamReviewItemModel({
    required this.questionId,
    required this.questionText,
    required this.choices,
    required this.correctChoiceId,
    required this.selectedChoiceId,
    required this.isCorrect,
    required this.wasFlagged,
    this.explanation,
    this.topicId,
    this.topicName,
  });

  factory ExamReviewItemModel.fromJson(Map<String, dynamic> json) {
    return ExamReviewItemModel(
      questionId: json['questionId'] as String,
      questionText: json['questionText'] as String,
      choices: (json['choices'] as List)
          .map((c) => ExamAnswerChoiceModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      correctChoiceId: json['correctChoiceId'] as String,
      selectedChoiceId: json['selectedChoiceId'] as String?,
      isCorrect: json['isCorrect'] as bool,
      wasFlagged: json['wasFlagged'] as bool? ?? false,
      explanation: json['explanation'] as String?,
      topicId: json['topicId'] as String?,
      topicName: json['topicName'] as String?,
    );
  }

  final String questionId;
  final String questionText;
  final List<ExamAnswerChoiceModel> choices;
  final String correctChoiceId;
  final String? selectedChoiceId;
  final bool isCorrect;
  final bool wasFlagged;
  final String? explanation;
  final String? topicId;
  final String? topicName;

  ExamReviewItem toEntity() => ExamReviewItem(
    questionId: questionId,
    questionText: questionText,
    choices: choices.map((c) => c.toEntity()).toList(),
    correctChoiceId: correctChoiceId,
    selectedChoiceId: selectedChoiceId,
    isCorrect: isCorrect,
    wasFlagged: wasFlagged,
    explanation: explanation,
    topicId: topicId,
    topicName: topicName,
  );
}
