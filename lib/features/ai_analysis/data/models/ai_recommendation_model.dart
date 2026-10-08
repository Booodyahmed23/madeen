import '../../domain/entities/ai_recommendation.dart';

class AiRecommendationModel {
  const AiRecommendationModel({
    required this.text,
    this.topicId,
    this.topicName,
  });

  factory AiRecommendationModel.fromJson(Map<String, dynamic> json) {
    return AiRecommendationModel(
      text: json['text'] as String,
      topicId: json['topicId'] as String?,
      topicName: json['topicName'] as String?,
    );
  }

  final String text;
  final String? topicId;
  final String? topicName;

  AiRecommendation toEntity() =>
      AiRecommendation(text: text, topicId: topicId, topicName: topicName);
}
