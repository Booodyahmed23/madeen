import '../../domain/entities/study_session_bundle.dart';
import 'question_model.dart';

class StudySessionBundleModel {
  const StudySessionBundleModel({
    required this.sessionId,
    required this.questions,
  });

  factory StudySessionBundleModel.fromJson(Map<String, dynamic> json) {
    return StudySessionBundleModel(
      sessionId: json['sessionId'] as String,
      questions: (json['questions'] as List)
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  final String sessionId;
  final List<QuestionModel> questions;

  StudySessionBundle toEntity() => StudySessionBundle(
    sessionId: sessionId,
    questions: questions.map((q) => q.toEntity()).toList(),
  );
}
