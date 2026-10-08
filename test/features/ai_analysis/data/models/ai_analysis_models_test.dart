import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_analysis/data/models/ai_analysis_metadata_model.dart';
import 'package:mobile/features/ai_analysis/data/models/ai_analysis_model.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_insight.dart';

void main() {
  group('AiAnalysisModel.fromJson', () {
    test('parses a full overview-shaped response', () {
      final json = {
        'metadata': {
          'scope': 'OVERALL',
          'status': 'READY',
          'generatedAt': '2026-09-16T09:05:00.000Z',
          'basedOnAttemptCount': 6,
        },
        'overallSummary': 'Your recent practice shows...',
        'strengths': [
          {
            'kind': 'STRENGTH',
            'text': 'Strong in Budgeting.',
            'topicId': 'topic-budgeting',
            'topicName': 'Budgeting',
            'supportingMetricPercent': 90.0,
          },
        ],
        'weaknesses': [
          {
            'kind': 'WEAKNESS',
            'text': 'Needs review in Variance Analysis.',
            'topicId': 'topic-variance-analysis',
            'topicName': 'Variance Analysis',
            'supportingMetricPercent': 55.0,
          },
        ],
        'topicInsights': [
          {
            'topicId': 'topic-budgeting',
            'topicName': 'Budgeting',
            'accuracyPercent': 90.0,
            'answered': 20,
            'correct': 18,
            'interpretation': 'Solid grasp.',
            'recommendedAction': 'Keep reinforcing.',
          },
        ],
        'recurringPatterns': [
          {
            'kind': 'PATTERN',
            'text': 'Some attempts include unanswered questions.',
          },
        ],
        'recommendations': [
          {
            'text': 'Review Variance Analysis.',
            'topicId': 'topic-variance-analysis',
            'topicName': 'Variance Analysis',
          },
        ],
      };

      final model = AiAnalysisModel.fromJson(json);

      expect(model.metadata.scope, AiAnalysisScope.overall);
      expect(model.metadata.status, AiAnalysisStatus.ready);
      expect(model.metadata.basedOnAttemptCount, 6);
      expect(model.strengths, hasLength(1));
      expect(model.strengths.single.kind, AiInsightKind.strength);
      expect(model.weaknesses.single.supportingMetricPercent, 55.0);
      expect(model.topicInsights.single.topicName, 'Budgeting');
      expect(model.recurringPatterns.single.kind, AiInsightKind.pattern);
      expect(model.recommendations.single.topicId, 'topic-variance-analysis');
    });

    test('parses a minimal insufficient-data response with omitted lists', () {
      final json = {
        'metadata': {
          'scope': 'OVERALL',
          'status': 'INSUFFICIENT_DATA',
          'generatedAt': '2026-09-16T09:05:00.000Z',
          'basedOnAttemptCount': 0,
        },
        'overallSummary': 'Complete a session to unlock insights.',
      };

      final model = AiAnalysisModel.fromJson(json);

      expect(model.metadata.status, AiAnalysisStatus.insufficientData);
      expect(model.strengths, isEmpty);
      expect(model.weaknesses, isEmpty);
      expect(model.topicInsights, isEmpty);
      expect(model.recurringPatterns, isEmpty);
      expect(model.recommendations, isEmpty);
    });

    test('parses a topic-scoped response with basedOnAttemptCount omitted', () {
      final json = {
        'metadata': {
          'scope': 'TOPIC',
          'status': 'READY',
          'generatedAt': '2026-09-16T09:05:00.000Z',
          'topicId': 'topic-budgeting',
        },
        'overallSummary': 'Your performance in Budgeting is strong.',
        'topicInsights': [
          {
            'topicId': 'topic-budgeting',
            'topicName': 'Budgeting',
            'accuracyPercent': 90.0,
            'answered': 20,
            'correct': 18,
            'interpretation': 'Solid grasp.',
            'recommendedAction': 'Keep reinforcing.',
          },
        ],
      };

      final model = AiAnalysisModel.fromJson(json);

      expect(model.metadata.scope, AiAnalysisScope.topic);
      expect(model.metadata.basedOnAttemptCount, isNull);
      expect(model.metadata.topicId, 'topic-budgeting');
    });
  });

  group('AiAnalysisModel.toEntity', () {
    test('maps every field onto the domain entity', () {
      final model = AiAnalysisModel(
        metadata: AiAnalysisMetadataModel(
          scope: AiAnalysisScope.overall,
          status: AiAnalysisStatus.ready,
          generatedAt: DateTime(2026, 9, 16, 9),
          basedOnAttemptCount: 6,
        ),
        overallSummary: 'Summary.',
      );
      final entity = model.toEntity();
      expect(entity.overallSummary, 'Summary.');
      expect(entity.metadata.scope, AiAnalysisScope.overall);
      expect(entity.metadata.basedOnAttemptCount, 6);
    });
  });
}
