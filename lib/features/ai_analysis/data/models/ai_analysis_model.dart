import '../../domain/entities/ai_analysis.dart';
import 'ai_analysis_metadata_model.dart';
import 'ai_insight_model.dart';
import 'ai_recommendation_model.dart';
import 'ai_topic_insight_model.dart';

class AiAnalysisModel {
  const AiAnalysisModel({
    required this.metadata,
    required this.overallSummary,
    this.strengths = const [],
    this.weaknesses = const [],
    this.topicInsights = const [],
    this.recurringPatterns = const [],
    this.recommendations = const [],
  });

  factory AiAnalysisModel.fromJson(Map<String, dynamic> json) {
    return AiAnalysisModel(
      metadata: AiAnalysisMetadataModel.fromJson(
        json['metadata'] as Map<String, dynamic>,
      ),
      overallSummary: json['overallSummary'] as String,
      strengths: _insightList(json['strengths']),
      weaknesses: _insightList(json['weaknesses']),
      topicInsights: (json['topicInsights'] as List? ?? const [])
          .map((e) => AiTopicInsightModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      recurringPatterns: _insightList(json['recurringPatterns']),
      recommendations: (json['recommendations'] as List? ?? const [])
          .map((e) => AiRecommendationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static List<AiInsightModel> _insightList(dynamic value) {
    return (value as List? ?? const [])
        .map((e) => AiInsightModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  final AiAnalysisMetadataModel metadata;
  final String overallSummary;
  final List<AiInsightModel> strengths;
  final List<AiInsightModel> weaknesses;
  final List<AiTopicInsightModel> topicInsights;
  final List<AiInsightModel> recurringPatterns;
  final List<AiRecommendationModel> recommendations;

  AiAnalysis toEntity() => AiAnalysis(
    metadata: metadata.toEntity(),
    overallSummary: overallSummary,
    strengths: strengths.map((e) => e.toEntity()).toList(),
    weaknesses: weaknesses.map((e) => e.toEntity()).toList(),
    topicInsights: topicInsights.map((e) => e.toEntity()).toList(),
    recurringPatterns: recurringPatterns.map((e) => e.toEntity()).toList(),
    recommendations: recommendations.map((e) => e.toEntity()).toList(),
  );
}
