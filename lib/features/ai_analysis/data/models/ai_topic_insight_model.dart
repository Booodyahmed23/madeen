import '../../domain/entities/ai_topic_insight.dart';

class AiTopicInsightModel {
  const AiTopicInsightModel({
    required this.topicId,
    required this.topicName,
    required this.accuracyPercent,
    required this.answered,
    required this.correct,
    required this.interpretation,
    required this.recommendedAction,
  });

  factory AiTopicInsightModel.fromJson(Map<String, dynamic> json) {
    return AiTopicInsightModel(
      topicId: json['topicId'] as String,
      topicName: json['topicName'] as String,
      accuracyPercent: (json['accuracyPercent'] as num).toDouble(),
      answered: (json['answered'] as num).toInt(),
      correct: (json['correct'] as num).toInt(),
      interpretation: json['interpretation'] as String,
      recommendedAction: json['recommendedAction'] as String,
    );
  }

  final String topicId;
  final String topicName;
  final double accuracyPercent;
  final int answered;
  final int correct;
  final String interpretation;
  final String recommendedAction;

  AiTopicInsight toEntity() => AiTopicInsight(
    topicId: topicId,
    topicName: topicName,
    accuracyPercent: accuracyPercent,
    answered: answered,
    correct: correct,
    interpretation: interpretation,
    recommendedAction: recommendedAction,
  );
}
