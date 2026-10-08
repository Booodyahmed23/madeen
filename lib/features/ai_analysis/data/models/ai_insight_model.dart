import '../../domain/entities/ai_insight.dart';

class AiInsightModel {
  const AiInsightModel({
    required this.kind,
    required this.text,
    this.topicId,
    this.topicName,
    this.supportingMetricPercent,
  });

  factory AiInsightModel.fromJson(Map<String, dynamic> json) {
    return AiInsightModel(
      kind: AiInsightKind.fromWire(json['kind'] as String),
      text: json['text'] as String,
      topicId: json['topicId'] as String?,
      topicName: json['topicName'] as String?,
      supportingMetricPercent: (json['supportingMetricPercent'] as num?)
          ?.toDouble(),
    );
  }

  final AiInsightKind kind;
  final String text;
  final String? topicId;
  final String? topicName;
  final double? supportingMetricPercent;

  AiInsight toEntity() => AiInsight(
    kind: kind,
    text: text,
    topicId: topicId,
    topicName: topicName,
    supportingMetricPercent: supportingMetricPercent,
  );
}
