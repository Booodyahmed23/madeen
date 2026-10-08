import '../../domain/entities/ai_analysis_metadata.dart';
import '../../domain/entities/ai_analysis_scope.dart';

class AiAnalysisMetadataModel {
  const AiAnalysisMetadataModel({
    required this.scope,
    required this.status,
    required this.generatedAt,
    this.basedOnAttemptCount,
    this.topicId,
    this.attemptId,
  });

  factory AiAnalysisMetadataModel.fromJson(Map<String, dynamic> json) {
    return AiAnalysisMetadataModel(
      scope: AiAnalysisScope.fromWire(json['scope'] as String),
      status: AiAnalysisStatus.fromWire(json['status'] as String),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      basedOnAttemptCount: (json['basedOnAttemptCount'] as num?)?.toInt(),
      topicId: json['topicId'] as String?,
      attemptId: json['attemptId'] as String?,
    );
  }

  final AiAnalysisScope scope;
  final AiAnalysisStatus status;
  final DateTime generatedAt;
  final int? basedOnAttemptCount;
  final String? topicId;
  final String? attemptId;

  AiAnalysisMetadata toEntity() => AiAnalysisMetadata(
    scope: scope,
    status: status,
    generatedAt: generatedAt,
    basedOnAttemptCount: basedOnAttemptCount,
    topicId: topicId,
    attemptId: attemptId,
  );
}
