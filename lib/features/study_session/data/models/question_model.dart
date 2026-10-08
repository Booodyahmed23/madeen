import '../../domain/entities/question.dart';
import '../../domain/entities/question_type.dart';
import 'answer_choice_model.dart';

/// JSON shape for one question **as presented to the student** — per
/// STUDY_SESSION_API_REQUIREMENTS.md, this response must never include a
/// correct-answer indicator or explanation. Only `id`/`text`/`type`/
/// `choices`/`difficulty` are parsed; if a real backend response ever
/// included more, this model simply wouldn't read it — but the contract
/// document is explicit that it must not be sent at all.
class QuestionModel {
  const QuestionModel({
    required this.id,
    required this.text,
    required this.type,
    required this.choices,
    this.difficulty,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      text: json['text'] as String,
      type: QuestionType.fromWire(
        json['type'] as String? ?? 'MULTIPLE_CHOICE_SINGLE',
      ),
      choices: (json['choices'] as List)
          .map((c) => AnswerChoiceModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      difficulty: json['difficulty'] as String?,
    );
  }

  final String id;
  final String text;
  final QuestionType type;
  final List<AnswerChoiceModel> choices;
  final String? difficulty;

  Question toEntity() => Question(
    id: id,
    text: text,
    type: type,
    choices: choices.map((c) => c.toEntity()).toList(),
    difficulty: difficulty,
  );
}
