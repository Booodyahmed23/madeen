import '../../domain/entities/exam_question.dart';
import '../../domain/entities/exam_question_type.dart';
import 'exam_answer_choice_model.dart';

/// JSON shape for one question **as presented to the student** — per
/// EXAM_SIMULATION_API_REQUIREMENTS.md, this response must never include a
/// correct-answer indicator, explanation, or any topic/curriculum context.
class ExamQuestionModel {
  const ExamQuestionModel({
    required this.id,
    required this.text,
    required this.type,
    required this.choices,
  });

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    return ExamQuestionModel(
      id: json['id'] as String,
      text: json['text'] as String,
      type: ExamQuestionType.fromWire(
        json['type'] as String? ?? 'MULTIPLE_CHOICE_SINGLE',
      ),
      choices: (json['choices'] as List)
          .map((c) => ExamAnswerChoiceModel.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String text;
  final ExamQuestionType type;
  final List<ExamAnswerChoiceModel> choices;

  ExamQuestion toEntity() => ExamQuestion(
    id: id,
    text: text,
    type: type,
    choices: choices.map((c) => c.toEntity()).toList(),
  );
}
