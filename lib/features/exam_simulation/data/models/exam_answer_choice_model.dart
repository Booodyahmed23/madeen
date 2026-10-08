import '../../domain/entities/exam_answer_choice.dart';

class ExamAnswerChoiceModel {
  const ExamAnswerChoiceModel({
    required this.id,
    required this.text,
    this.order = 0,
  });

  factory ExamAnswerChoiceModel.fromJson(Map<String, dynamic> json) {
    return ExamAnswerChoiceModel(
      id: json['id'] as String,
      text: json['text'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String text;
  final int order;

  ExamAnswerChoice toEntity() =>
      ExamAnswerChoice(id: id, text: text, order: order);
}
