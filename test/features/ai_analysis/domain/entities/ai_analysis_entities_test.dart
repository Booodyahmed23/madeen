import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_insight.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_recommendation.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_topic_insight.dart';

AiAnalysisMetadata _metadata({
  AiAnalysisScope scope = AiAnalysisScope.overall,
  AiAnalysisStatus status = AiAnalysisStatus.ready,
}) {
  return AiAnalysisMetadata(
    scope: scope,
    status: status,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 6,
  );
}

void main() {
  group('AiAnalysisScope wire mapping', () {
    test('round-trips through toWire/fromWire', () {
      for (final scope in AiAnalysisScope.values) {
        expect(AiAnalysisScope.fromWire(scope.toWire()), scope);
      }
    });

    test('fromWire throws on an unknown value', () {
      expect(
        () => AiAnalysisScope.fromWire('SOMETHING_ELSE'),
        throwsFormatException,
      );
    });
  });

  group('AiAnalysisStatus wire mapping', () {
    test('round-trips through toWire/fromWire', () {
      for (final status in AiAnalysisStatus.values) {
        expect(AiAnalysisStatus.fromWire(status.toWire()), status);
      }
    });

    test('fromWire throws on an unknown value', () {
      expect(
        () => AiAnalysisStatus.fromWire('SOMETHING_ELSE'),
        throwsFormatException,
      );
    });
  });

  group('AiInsightKind wire mapping', () {
    test('round-trips through toWire/fromWire', () {
      for (final kind in AiInsightKind.values) {
        expect(AiInsightKind.fromWire(kind.toWire()), kind);
      }
    });

    test('fromWire throws on an unknown value', () {
      expect(
        () => AiInsightKind.fromWire('SOMETHING_ELSE'),
        throwsFormatException,
      );
    });
  });

  group('AiAnalysis.hasInsights', () {
    test('is false when every list is empty', () {
      final analysis = AiAnalysis(
        metadata: _metadata(status: AiAnalysisStatus.insufficientData),
        overallSummary: 'Complete a session to unlock insights.',
      );
      expect(analysis.hasInsights, isFalse);
    });

    test('is true when at least one list is non-empty', () {
      final analysis = AiAnalysis(
        metadata: _metadata(),
        overallSummary: 'Overall summary.',
        recommendations: const [AiRecommendation(text: 'Review Budgeting.')],
      );
      expect(analysis.hasInsights, isTrue);
    });

    test('is true when only topicInsights is non-empty', () {
      final analysis = AiAnalysis(
        metadata: _metadata(scope: AiAnalysisScope.topic),
        overallSummary: 'Topic summary.',
        topicInsights: const [
          AiTopicInsight(
            topicId: 't1',
            topicName: 'Budgeting',
            accuracyPercent: 90,
            answered: 20,
            correct: 18,
            interpretation: 'Solid grasp of this topic.',
            recommendedAction: 'Keep reinforcing it.',
          ),
        ],
      );
      expect(analysis.hasInsights, isTrue);
    });
  });

  group('AiAnalysisMetadata', () {
    test(
      'basedOnAttemptCount is null for topic/attempt scope by convention',
      () {
        final topicMetadata = AiAnalysisMetadata(
          scope: AiAnalysisScope.topic,
          status: AiAnalysisStatus.ready,
          generatedAt: DateTime(2026, 9, 16),
          topicId: 't1',
        );
        expect(topicMetadata.basedOnAttemptCount, isNull);
        expect(topicMetadata.topicId, 't1');
        expect(topicMetadata.attemptId, isNull);
      },
    );
  });
}
