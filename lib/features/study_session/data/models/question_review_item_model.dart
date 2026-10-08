import '../../domain/entities/question_review_item.dart';
import 'answer_choice_model.dart';

class QuestionReviewItemModel {
  const QuestionReviewItemModel({
    required this.questionId,
    required this.questionText,
    required this.choices,
    required this.correctChoiceId,
    required this.selectedChoiceId,
    required this.isCorrect,
    this.explanation,
  });

  factory QuestionReviewItemModel.fromJson(Map<String, dynamic> json) {
    return QuestionReviewItemModel(
      questionId: json['questionId'] as String,
      questionText: json['questionText'] as String,
      choices: (json['choices'] as List)
          .map((c) => AnswerChoiceModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      correctChoiceId: json['correctChoiceId'] as String,
      selectedChoiceId: json['selectedChoiceId'] as String?,
      isCorrect: json['isCorrect'] as bool,
      explanation: json['explanation'] as String?,
    );
  }

  final String questionId;
  final String questionText;
  final List<AnswerChoiceModel> choices;
  final String correctChoiceId;
  final String? selectedChoiceId;
  final bool isCorrect;
  final String? explanation;

  QuestionReviewItem toEntity() => QuestionReviewItem(
    questionId: questionId,
    questionText: questionText,
    choices: choices.map((c) => c.toEntity()).toList(),
    correctChoiceId: correctChoiceId,
    selectedChoiceId: selectedChoiceId,
    isCorrect: isCorrect,
    explanation: explanation,
  );
}
