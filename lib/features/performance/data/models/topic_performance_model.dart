import '../../domain/entities/topic_performance.dart';

class TopicPerformanceModel {
  const TopicPerformanceModel({
    required this.topicId,
    required this.topicName,
    required this.questionsAttempted,
    required this.answered,
    required this.correct,
    required this.wrong,
    this.averageTimePerQuestionSeconds,
  });

  factory TopicPerformanceModel.fromJson(Map<String, dynamic> json) {
    return TopicPerformanceModel(
      topicId: json['topicId'] as String,
      topicName: json['topicName'] as String,
      questionsAttempted: (json['questionsAttempted'] as num).toInt(),
      answered: (json['answered'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      wrong: (json['wrong'] as num).toInt(),
      averageTimePerQuestionSeconds:
          (json['averageTimePerQuestionSeconds'] as num?)?.toInt(),
    );
  }

  final String topicId;
  final String topicName;
  final int questionsAttempted;
  final int answered;
  final int correct;
  final int wrong;
  final int? averageTimePerQuestionSeconds;

  Map<String, dynamic> toJson() => {
    'topicId': topicId,
    'topicName': topicName,
    'questionsAttempted': questionsAttempted,
    'answered': answered,
    'correct': correct,
    'wrong': wrong,
    'averageTimePerQuestionSeconds': averageTimePerQuestionSeconds,
  };

  TopicPerformance toEntity() => TopicPerformance(
    topicId: topicId,
    topicName: topicName,
    questionsAttempted: questionsAttempted,
    answered: answered,
    correct: correct,
    wrong: wrong,
    averageTimePerQuestion: averageTimePerQuestionSeconds == null
        ? null
        : Duration(seconds: averageTimePerQuestionSeconds!),
  );
}
