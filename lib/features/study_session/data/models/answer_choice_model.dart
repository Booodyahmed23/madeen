import '../../domain/entities/answer_choice.dart';

class AnswerChoiceModel {
  const AnswerChoiceModel({
    required this.id,
    required this.text,
    this.order = 0,
  });

  factory AnswerChoiceModel.fromJson(Map<String, dynamic> json) {
    return AnswerChoiceModel(
      id: json['id'] as String,
      text: json['text'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String text;
  final int order;

  AnswerChoice toEntity() => AnswerChoice(id: id, text: text, order: order);
}
